import pytest
from botocore.exceptions import ClientError

import tagger


class FakeS3:
    """Stand-in for the S3 client, recording put calls.

    `errors` maps an object key to the exception get_object_tagging should
    raise for that key. A `None` entry is the fallback applied to every key
    that has no key-specific entry, which lets a single call site express
    "every call in this test fails the same way."
    """

    def __init__(self, tag_set=None, errors=None):
        self.tag_set = tag_set if tag_set is not None else []
        self.errors = errors or {}
        self.put_calls = []

    def get_object_tagging(self, **kwargs):
        error = self.errors.get(kwargs["Key"], self.errors.get(None))
        if error is not None:
            raise error
        return {"TagSet": list(self.tag_set)}

    def put_object_tagging(self, **kwargs):
        self.put_calls.append(kwargs)


def client_error(code, operation="GetObjectTagging"):
    return ClientError({"Error": {"Code": code, "Message": code}}, operation)


def s3_event(*keys, bucket="hfs-bch-raw-output"):
    return {
        "Records": [
            {"s3": {"bucket": {"name": bucket}, "object": {"key": key}}}
            for key in keys
        ]
    }


@pytest.mark.parametrize(
    "key",
    [
        "run-1/out/sample.bam",
        "run-1/out/sample.bam.bai",
        "run-1/out/coverage.bedgraph",
        "run-1/out/depth.bw",
        "run-1/out/variants.vcf.gz",
        "run-1/out/no-extension",
        "run-1/out/logs.json.gz",
    ],
)
def test_should_expire_true_for_disposable_outputs(key):
    assert tagger.should_expire(key) is True


@pytest.mark.parametrize(
    "key",
    [
        "run-1/logs/task.log",
        "run-1/out/manifest.json",
        "run-1/logs/TASK.LOG",
        "run-1/out/MANIFEST.JSON",
    ],
)
def test_should_expire_false_for_retained_suffixes(key):
    assert tagger.should_expire(key) is False


def test_record_key_decodes_plus_and_percent_escapes():
    record = s3_event("run+1/out/my+file.bam")["Records"][0]
    assert tagger.record_key(record) == ("hfs-bch-raw-output", "run 1/out/my file.bam")

    record = s3_event("run-1/out/a%20b.bam")["Records"][0]
    assert tagger.record_key(record) == ("hfs-bch-raw-output", "run-1/out/a b.bam")


def test_tag_for_expiry_preserves_existing_tags():
    client = FakeS3(tag_set=[{"Key": "created_by", "Value": "terraform"}])

    tagger.tag_for_expiry(client, "bucket", "run-1/out/sample.bam")

    assert client.put_calls == [
        {
            "Bucket": "bucket",
            "Key": "run-1/out/sample.bam",
            "Tagging": {
                "TagSet": [
                    {"Key": "created_by", "Value": "terraform"},
                    {"Key": "expire", "Value": "true"},
                ]
            },
        }
    ]


def test_tag_for_expiry_replaces_an_existing_expire_tag():
    client = FakeS3(tag_set=[{"Key": "expire", "Value": "false"}])

    tagger.tag_for_expiry(client, "bucket", "run-1/out/sample.bam")

    assert client.put_calls[0]["Tagging"]["TagSet"] == [
        {"Key": "expire", "Value": "true"}
    ]


@pytest.mark.parametrize("missing_var", ["EXPIRE_TAG_KEY", "EXPIRE_TAG_VALUE"])
def test_tag_for_expiry_raises_when_a_required_env_var_is_missing(monkeypatch, missing_var):
    monkeypatch.delenv(missing_var, raising=False)
    client = FakeS3()

    with pytest.raises(RuntimeError, match=missing_var):
        tagger.tag_for_expiry(client, "bucket", "run-1/out/sample.bam")


def test_handler_skips_retained_suffixes_without_calling_s3():
    client = FakeS3()

    tagger.handler(s3_event("run-1/logs/task.log"), None, client=client)

    assert client.put_calls == []


def test_handler_swallows_a_deleted_object():
    client = FakeS3(errors={None: client_error("NoSuchKey")})

    tagger.handler(s3_event("run-1/out/sample.bam"), None, client=client)

    assert client.put_calls == []


def test_handler_reraises_unexpected_client_errors():
    client = FakeS3(errors={None: client_error("AccessDenied")})

    with pytest.raises(ClientError):
        tagger.handler(s3_event("run-1/out/sample.bam"), None, client=client)


def test_handler_processes_every_record_in_a_batch():
    client = FakeS3()
    event = s3_event(
        "run-1/out/a.bam", "run-1/logs/a.log", "run-1/out/b.bam", bucket="b"
    )

    tagger.handler(event, None, client=client)

    assert [call["Key"] for call in client.put_calls] == [
        "run-1/out/a.bam",
        "run-1/out/b.bam",
    ]


def test_handler_tags_other_records_then_raises_on_unexpected_error():
    client = FakeS3(errors={"run-1/out/b.bam": client_error("InvalidTag")})
    event = s3_event(
        "run-1/out/a.bam", "run-1/out/b.bam", "run-1/out/c.bam", bucket="b"
    )

    with pytest.raises(ClientError):
        tagger.handler(event, None, client=client)

    assert [call["Key"] for call in client.put_calls] == [
        "run-1/out/a.bam",
        "run-1/out/c.bam",
    ]


def test_handler_tags_other_records_and_raises_on_a_malformed_middle_record():
    client = FakeS3()
    event = {
        "Records": [
            {"s3": {"bucket": {"name": "b"}, "object": {"key": "run-1/out/a.bam"}}},
            {"s3": {"bucket": {"name": "b"}, "object": {}}},
            {"s3": {"bucket": {"name": "b"}, "object": {"key": "run-1/out/c.bam"}}},
        ]
    }

    with pytest.raises(KeyError):
        tagger.handler(event, None, client=client)

    assert [call["Key"] for call in client.put_calls] == [
        "run-1/out/a.bam",
        "run-1/out/c.bam",
    ]


def test_handler_tags_other_records_and_does_not_raise_on_a_deleted_middle_record():
    client = FakeS3(errors={"run-1/out/b.bam": client_error("NoSuchKey")})
    event = s3_event(
        "run-1/out/a.bam", "run-1/out/b.bam", "run-1/out/c.bam", bucket="b"
    )

    tagger.handler(event, None, client=client)

    assert [call["Key"] for call in client.put_calls] == [
        "run-1/out/a.bam",
        "run-1/out/c.bam",
    ]
