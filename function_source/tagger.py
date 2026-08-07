"""Tag HealthOmics run outputs so an S3 lifecycle rule can expire them early.

The bucket's lifecycle rules cannot express "everything except these suffixes":
S3 filters offer no suffix matching and no negation. So this function evaluates
the exclusion — it sees the full key — and tags what should expire. Objects whose
keys end in a retained suffix are deliberately left untagged, which the 90-day
catch-all rule then governs.
"""

import logging
import urllib.parse

import boto3
from botocore.exceptions import ClientError

RETAINED_SUFFIXES = (".log", ".json")
TAG_KEY = "retention"
TAG_VALUE = "transient"

# The object was removed between the notification and the tagging call. Routine
# when HealthOmics cleans up its own intermediates, and nothing is left to expire.
GONE_ERROR_CODES = ("NoSuchKey", "NoSuchVersion", "404")

logger = logging.getLogger()
logger.setLevel(logging.INFO)


def is_transient(key):
    """True when the object should be tagged for early expiration.

    Matched case-insensitively so an unexpectedly-cased run log is retained
    rather than expired — absence of the tag is the fail-safe direction.
    """
    return not key.lower().endswith(RETAINED_SUFFIXES)


def record_key(record):
    """Extract (bucket, key) from a single S3 event record, key percent-decoded.

    Raises KeyError if the record is missing either field.
    """
    return (
        record["s3"]["bucket"]["name"],
        urllib.parse.unquote_plus(record["s3"]["object"]["key"]),
    )


def object_keys(event):
    """Yield (bucket, key) for each record, with the key percent-decoded."""
    for record in event.get("Records", []):
        yield record_key(record)


def tag_transient(client, bucket, key):
    """Add the expiry tag, preserving any tags already on the object.

    PutObjectTagging replaces the whole tag set, so read-modify-write. This
    function owns the `retention` tag key on this bucket and overwrites any
    existing value, so the key must not be used for any other purpose here.
    """
    existing = client.get_object_tagging(Bucket=bucket, Key=key)["TagSet"]
    tags = [tag for tag in existing if tag["Key"] != TAG_KEY]
    tags.append({"Key": TAG_KEY, "Value": TAG_VALUE})
    client.put_object_tagging(Bucket=bucket, Key=key, Tagging={"TagSet": tags})


def handler(event, context, client=None):
    """Tag every eligible record, even if some records fail or are malformed.

    One bad or malformed record must not stop the rest of the batch from being
    tagged, so both extraction failures and unexpected tagging errors are
    collected rather than raised immediately. Once every record has been
    attempted, the invocation still fails (re-raising the last error) so
    Lambda records and retries it — there is no other monitoring on this
    function, so that failed-invocation signal is what surfaces problems.
    """
    client = client or boto3.client("s3")

    failures = []
    for record in event.get("Records", []):
        try:
            bucket, key = record_key(record)
        except KeyError as error:
            logger.error("malformed record, skipping: %r (%s)", record, error)
            failures.append(error)
            continue

        if not is_transient(key):
            logger.info("retaining s3://%s/%s", bucket, key)
            continue
        try:
            tag_transient(client, bucket, key)
        except ClientError as error:
            if error.response["Error"]["Code"] in GONE_ERROR_CODES:
                logger.info("skipping s3://%s/%s: object no longer exists", bucket, key)
                continue
            logger.error("failed to tag s3://%s/%s: %s", bucket, key, error)
            failures.append(error)

    if failures:
        raise failures[-1]
