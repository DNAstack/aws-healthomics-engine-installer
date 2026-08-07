import pytest
from botocore.exceptions import ClientError

import tagger


class FakeS3:
    """Minimal stand-in for the S3 client, recording put calls."""

    def __init__(self, tag_set=None, get_error=None):
        self.tag_set = tag_set if tag_set is not None else []
        self.get_error = get_error
        self.put_calls = []

    def get_object_tagging(self, **kwargs):
        if self.get_error is not None:
            raise self.get_error
        return {"TagSet": list(self.tag_set)}

    def put_object_tagging(self, **kwargs):
        self.put_calls.append(kwargs)


def client_error(code, operation="GetObjectTagging"):
    return ClientError({"Error": {"Code": code, "Message": code}}, operation)


def s3_event(key, bucket="hfs-bch-raw-output"):
    return {"Records": [{"s3": {"bucket": {"name": bucket}, "object": {"key": key}}}]}


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
def test_is_transient_true_for_disposable_outputs(key):
    assert tagger.is_transient(key) is True


@pytest.mark.parametrize(
    "key",
    [
        "run-1/logs/task.log",
        "run-1/out/manifest.json",
        "run-1/logs/TASK.LOG",
        "run-1/out/MANIFEST.JSON",
    ],
)
def test_is_transient_false_for_retained_suffixes(key):
    assert tagger.is_transient(key) is False


def test_object_keys_decodes_plus_and_percent_escapes():
    event = s3_event("run+1/out/my+file.bam")
    assert list(tagger.object_keys(event)) == [
        ("hfs-bch-raw-output", "run 1/out/my file.bam")
    ]

    event = s3_event("run-1/out/a%20b.bam")
    assert list(tagger.object_keys(event)) == [
        ("hfs-bch-raw-output", "run-1/out/a b.bam")
    ]


def test_tag_transient_preserves_existing_tags():
    client = FakeS3(tag_set=[{"Key": "created_by", "Value": "terraform"}])

    tagger.tag_transient(client, "bucket", "run-1/out/sample.bam")

    assert client.put_calls == [
        {
            "Bucket": "bucket",
            "Key": "run-1/out/sample.bam",
            "Tagging": {
                "TagSet": [
                    {"Key": "created_by", "Value": "terraform"},
                    {"Key": "retention", "Value": "transient"},
                ]
            },
        }
    ]


def test_tag_transient_replaces_an_existing_retention_tag():
    client = FakeS3(tag_set=[{"Key": "retention", "Value": "keep"}])

    tagger.tag_transient(client, "bucket", "run-1/out/sample.bam")

    assert client.put_calls[0]["Tagging"]["TagSet"] == [
        {"Key": "retention", "Value": "transient"}
    ]


def test_handler_skips_retained_suffixes_without_calling_s3():
    client = FakeS3()

    tagger.handler(s3_event("run-1/logs/task.log"), None, client=client)

    assert client.put_calls == []


def test_handler_swallows_a_deleted_object():
    client = FakeS3(get_error=client_error("NoSuchKey"))

    tagger.handler(s3_event("run-1/out/sample.bam"), None, client=client)

    assert client.put_calls == []


def test_handler_reraises_unexpected_client_errors():
    client = FakeS3(get_error=client_error("AccessDenied"))

    with pytest.raises(ClientError):
        tagger.handler(s3_event("run-1/out/sample.bam"), None, client=client)


def test_handler_processes_every_record_in_a_batch():
    client = FakeS3()
    event = {
        "Records": [
            {"s3": {"bucket": {"name": "b"}, "object": {"key": "run-1/out/a.bam"}}},
            {"s3": {"bucket": {"name": "b"}, "object": {"key": "run-1/logs/a.log"}}},
            {"s3": {"bucket": {"name": "b"}, "object": {"key": "run-1/out/b.bam"}}},
        ]
    }

    tagger.handler(event, None, client=client)

    assert [call["Key"] for call in client.put_calls] == [
        "run-1/out/a.bam",
        "run-1/out/b.bam",
    ]
