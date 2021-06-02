/* eslint-disable no-console */
/* Handles the following event types: INSERT, MODIFY and REMOVE for Transactions table DynamoDB Stream. */

import { sendDynamoRecordsToSqs } from '@endpoint/dynamodb-streams-event-service-enqueuer';
import { Environment } from '@endpoint/dynamodb-streams-event-service-enqueuer/dist/Environment';
import { DynamoDBStreams } from 'aws-sdk';

console.log(`Loading function ${process.env.AWS_LAMBDA_FUNCTION_NAME}...`);

export const lambdaHandler = async (event: { Records: DynamoDBStreams.RecordList }) => {
  console.log(`event: ${JSON.stringify(event)}`);

  const env = process.env.NODE_ENV as Environment;

  await sendDynamoRecordsToSqs({ tableName: 'Transactions', records: event.Records }, env);
};
