"""SQS -> Lambda worker.

Handles two kinds of messages:
  * S3 event notifications (a file landed under uploads/)
  * plain JSON jobs sent by the backend

Replace `handle_job` / `handle_s3_object` with your real processing
(thumbnails, virus scan, parsing, ...).
"""

import json
import logging
import os
from urllib.parse import unquote_plus

logger = logging.getLogger()
logger.setLevel(os.environ.get("LOG_LEVEL", "INFO"))


def lambda_handler(event, context):
    failures = []

    for record in event.get("Records", []):
        try:
            process_record(record)
        except Exception:  # noqa: BLE001 - we want to catch everything per message
            logger.exception("Failed message %s", record.get("messageId"))
            failures.append({"itemIdentifier": record["messageId"]})

    # Partial batch response: only these messages are retried.
    return {"batchItemFailures": failures}


def process_record(record):
    body = json.loads(record["body"])

    if body.get("Event") == "s3:TestEvent":
        logger.info("Ignoring S3 test event")
        return

    if "Records" in body:
        for s3_record in body["Records"]:
            handle_s3_object(
                bucket=s3_record["s3"]["bucket"]["name"],
                key=unquote_plus(s3_record["s3"]["object"]["key"]),
                size=s3_record["s3"]["object"].get("size"),
            )
    else:
        handle_job(body)


def handle_s3_object(bucket, key, size):
    logger.info("New upload: s3://%s/%s (%s bytes)", bucket, key, size)


def handle_job(job):
    logger.info("Backend job received: %s", json.dumps(job))
