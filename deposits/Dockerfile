FROM public.ecr.aws/lambda/nodejs:12

COPY . /opt/app
WORKDIR /opt/app

ARG NPM_TOKEN

RUN npm config set '//registry.npmjs.org/:_authToken' "${NPM_TOKEN}"

RUN yarn

RUN yarn run build

CMD ["./dist/index.lambdaHandler"]