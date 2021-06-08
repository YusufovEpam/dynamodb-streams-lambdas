/* eslint-disable @typescript-eslint/naming-convention */
const sendDynamoRecordsToSqs = jest.fn();
const mockDynamodbStreamsEventServiceEnqueuer = {
  sendDynamoRecordsToSqs,
};

jest.mock('@endpoint/dynamodb-streams-event-service-enqueuer', () => mockDynamodbStreamsEventServiceEnqueuer);

const { lambdaHandler } = require('./index');

describe('lambda handler', () => {
  let procEnv: NodeJS.ProcessEnv;

  beforeEach(() => {
    procEnv = process.env;
    process.env = {
      NODE_ENV: 'development',
    };
  });

  afterEach(() => {
    process.env = procEnv;
  });

  it('it should call sendDynamoRecordsToSqs', () => {
    const event = {
      Records: [],
    };

    lambdaHandler(event);
    expect(sendDynamoRecordsToSqs).toHaveBeenCalledWith(
      { tableName: 'Users', records: event.Records },
      process.env.NODE_ENV,
    );
  });
});
