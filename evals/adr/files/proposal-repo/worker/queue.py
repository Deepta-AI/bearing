import json

import boto3

QUEUE_URL = "https://sqs.eu-west-1.amazonaws.com/000000000000/export-jobs"
sqs = boto3.client("sqs")


def enqueue(job):
    sqs.send_message(QueueUrl=QUEUE_URL, MessageBody=json.dumps(job))


def receive(max_messages=10):
    resp = sqs.receive_message(QueueUrl=QUEUE_URL, MaxNumberOfMessages=max_messages, WaitTimeSeconds=20)
    return resp.get("Messages", [])
