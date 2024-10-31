# Kestra orchestration with Snowflake and dbt

## Project Overview

This project focuses on exploring the Kestra orchestration platform and the capabilities that it offers. It consists of fetching API data on Premier League standings and scorers, ingesting that in our S3 data lake, then in Snowflake, and finally querying and combining these datasets with dbt, in order to reach certain insights. 

**Data sources** : [football-data.org API](https://www.football-data.org/)

**Tech stack** : Kestra, AWS, Snowflake, dbt, git


## Kestra summary

Kestra is a modern open-source orchestration and data workflow platform designed to manage complex workflows, automate data pipelines, and integrate with various tools in the data engineering ecosystem. Here's a brief overview of its key concepts and features:

### Key Concepts:

- **Workflows**: Defined sequences of tasks or steps. Each workflow is composed of multiple tasks, and can trigger sub-workflows or handle conditional execution.

- **Tasks**: The basic unit of execution within a workflow. Tasks can involve data processing, API calls, file transfers, and more.

- **Namespaces**: A namespace is used to provide logical isolation, e.g., to separate development and production environments. Namespaces are like folders on your file system — they organize flows into logical categories and can be nested to provide a hierarchical structure.

- **Triggers**: Used to automatically start workflows based on events (e.g., file arrivals, schedules).

- **Input/Output Management**: Kestra handles data inputs and outputs between tasks, simplifying data flow management.

- **Plugins**: They extend Kestra’s capabilities with [integrations](https://kestra.io/plugins) for databases, cloud platforms, and more (e.g., S3, GCS, SQL databases).

- **Error Handling**: Built-in retry mechanisms, error handling, and notifications in case of task failures.

- **Monitoring and UI**: Provides a web-based UI, for visualizing workflows, monitoring execution, and exploring task logs.


Two common orchestration tools are *Airflow* and *Data Factory*, and they are quite different to each other: Airflow is more code-oriented, while Data Factory is much more GUI-based. Let's see how *Kestra* compares to both of them: 

### Kestra vs. Airflow

- **Declarative Workflow Design**: Kestra simplifies workflow creation with its declarative YAML approach, making it less code-heavy than Airflow’s Python-based DAGs. This approach can reduce complexity for simpler workflows, and it makes easier for less code-savvy people to start developing in Kestra.

- **Built-In Integrations**: Kestra includes a wide range of pre-built plugins for connectors like HTTP, S3, Snowflake, and many more, eliminating the need for custom operators, which are common in Airflow.

- **Event-Driven Execution**: Kestra supports event-driven workflows directly, while Airflow primarily relies on time-based scheduling and additional plugins for event handling.

- **Simplified Docker Integration**: Kestra is designed to run well within Docker from the start, while Airflow's Docker setup can be more complex, especially when scaling with Kubernetes. This easy Docker setup makes Kestra very convenient for local development.

### Kestra vs. Azure Data Factory (ADF)

- **Vendor-Agnostic Flexibility**: Kestra is open-source and cloud-agnostic, offering flexibility across cloud providers. In contrast, Azure Data Factory is heavily integrated within the Azure ecosystem, making it best for Microsoft-centric environments.

- **Greater Extensibility**: Kestra’s plugin system allows for easier integration with various third-party systems, while ADF supports primarily Microsoft and common third-party tools, limiting extensibility outside the Azure ecosystem.

- **Complex Workflow Handling**: Kestra’s orchestration and custom branching capabilities handle complex workflows more naturally compared to ADF, which is more optimized for ETL/ELT pipelines but less so for complex multi-step workflows. Among the features it provides, are: conditional branching, subflows, sequential and parallel tasks, dynamic tasks, etc.


## Setting up the environment

1. **Install Docker and Docker Compose**

Ensure that both Docker and Docker Compose are installed on your local machine.
- [Install Docker](https://docs.docker.com/get-docker/)
- [Install Docker Compose](https://docs.docker.com/compose/install/)

2. **Install Kestra**

You can follow the guidelines to install kestra via docker-compose, [here](https://kestra.io/docs/installation/docker-compose), by downloading the docker compose file, and running:

```bash
docker-compose up -d
```
I updated/pinned the image versions of the Kestra and PostgreSQL images, to avoid possible compatibility issues in the future (e.g. instead of choosing always the "latest" image of both).

3. **AWS Access**

We create an *S3 bucket* (e.g. `my-data-lake`), as well as an IAM user (e.g. `kestra-IAM-user`) with credentials (Access Key ID & Secret Access Key), which will be used by Kestra to access S3. The IAM user should have permissions to write to the data lake / S3 bucket. These permissions can be managed by the Bucket Policy of the S3 bucket.

Moreover, we create an *IAM Role*, which will be used for creating the Snowflake -> S3 integration. This role (e.g. `my-snowflake-role`), also needs access to the S3 bucket, so that Snowflake can read from S3. We can manage that via the S3 Bucket Policy (or by creating a relevant IAM Policy and by assigning that IAM Policy to the IAM Role). We will also need to adapt the "trust relationships" of the IAM Role, for the Snowflake Storage Integration to take effect, as per the guidelines: Specifically, we need to *"Describe the integration"* in Snowflake, and make use of the `STORAGE_AWS_IAM_USER_ARN` and `STORAGE_AWS_EXTERNAL_ID` that appear, to update the trust relationship of the AWS IAM Role.


Example of the **Bucket Policy** for the S3 bucket:
```bash
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Principal": 
            {
                "AWS": "arn:aws:iam::XXXXXXXXXXXX:user/kestra-IAM-user"
            },
            "Action": "s3:ListBucket",
            "Resource": "arn:aws:s3:::my-data-lake"
        },
        {
            "Effect": "Allow",
            "Principal": 
            {
                "AWS": "arn:aws:iam::XXXXXXXXXXXX:user/kestra-IAM-user"
            },
            "Action": 
            [
                "s3:GetObject",
                "s3:PutObject",
                "s3:DeleteObject"
            ],
            "Resource": "arn:aws:s3:::my-data-lake/*"
        },
        {
            "Effect": "Allow",
            "Principal": 
            {
                "AWS": "arn:aws:iam::XXXXXXXXXXXX:role/my-snowflake-role"
            },
            "Action": 
            [
                "s3:GetObject",
                "s3:ListBucket"
            ],
            "Resource": 
            [
                "arn:aws:s3:::my-data-lake",
                "arn:aws:s3:::my-data-lake/*"
            ]
        }
    ]
}
```


Example of the **IAM Policy** that could be created (e.g. `access-to-my-s3-bucket`):
```bash
{
    "Version": "2012-10-17",
    "Statement": [
        {
            "Effect": "Allow",
            "Action": [
                "s3:ListBucket"
            ],
            "Resource": "arn:aws:s3:::my-data-lake"
        },
        {
            "Effect": "Allow",
            "Action": [
                "s3:PutObject",
                "s3:GetObject",
                "s3:DeleteObject",
                "s3:PutObjectAcl",
                "s3:GetObjectAcl",
                "s3:DeleteObjectVersion"
            ],
            "Resource": "arn:aws:s3:::my-data-lake/*"
        }
    ]
}
```

Kestra will access the bucket thanks to its `io.kestra.plugin.aws` plugin, in order to upload in S3 the files fetched from the API.
We can set up variables for the AWS user credentials, in our `docker-compose.yml` configuration, in order to avoid hardcoding these sensitive values directly into the Kestra flow yml.
These values need to be provided in `base64` encoding. This can be done by using the command: 

```bash
echo -n "secretValue" | base64
```

3. **Snowflake Access**

- Snowflake Account & Access Credentials: We obtain a Snowflake account and create a user with the necessary role and permissions to access the database and schema that we will use for testing.

- This repo includes an SQL file with the required commands for setting up the Database, Schema, a Storage Integration from Snowflake to S3, as well as an External Stage in Snowflake. The `Storage Integration` between the S3 data lake and Snowflake is what allows us to ingest all data into the RAW schema of Snowflake, via the *COPY INTO* command.

- Kestra will access Snowflake thanks to its `io.kestra.plugin.jdbc.snowflake` plugin. Similar to above, we can set up variables for the Snowflake account/URL/username/password, in our `docker-compose.yml` configuration, in order to avoid hardcoding these sensitive values directly into the Kestra flow yml.

4. **dbt Integration**

- *Local Development*: To firstly develop in dbt locally, it is recommended to create a Python virtual environment in our computer, to isolate dependencies. After we activate it, we can install dbt together with its Snowflake connector: `pip install dbt-snowflake`. This way, we will be able to run transformations independently before configuring them in Kestra. We also need to setup our `local profiles.yml` file accordingly, so that dbt can connect to our Snowflake instance. Then, we navigate to the root of the dbt project, and we can test/run all models. E.g. the command `dbt run`, will create all models from staging to mart, respecting the dependencies. We can generate the dependency graph of the models, via the commands `"dbt docs generate"` / `dbt docs serve`.

- *GitHub Access for dbt Project*: We want our Kestra local server to be able to access our dbt project that is stored in GitHub. To access the GitHub repository, we create a *personal access token*, and pass it also in the docker-compose configuration of the Kestra server, with based64 encoding. Kestra will access the repository via its `io.kestra.plugin.git` plugin, and run the dbt code thanks to the `io.kestra.plugin.dbt.cli` plugin. The dbt `profiles.yml` configuration can be provided directly within the dbt task of the Kestra flow, and any sensitive values will be added in the docker-compose yml configuration, and then passed via the Kestra "secrets" functionality into the task.

**Note:** If we were running Kestra in a *remote environment* such as a cloud provider or a remote server (e.g. AWS EC2, AWS EKS), *instead of locally*, we could use GitHub Actions to run Kestra workflows. We could use Github Actions to pull the latest configurations from our repository and apply them to our Kestra instance. Moreover, we could store our sensitive data as **Github Secrets**, then using these secrets in GitHub Actions workflows to securely pass them into our Docker Compose and Kestra YAML files during deployment.


## Walk through of Kestra flow
- The workflow defines a namespace (logical container) for our flow. Several flows can be part of a namespace.
- We have added a Trigger (cron schedule) so that the flow executes every 5 minutes.
- The flow consists of several tasks, which fetch data from the API, upload the data in json format to the S3 data lake, copy that into Snowflake, and finally run the dbt models that we have created. These dbt queries will flatten our semi-structured datasets, and join them together.
- Tasks that were used out-of-the-box, thanks to the available plugins: `io.kestra.plugin.core.http.Download`, `io.kestra.plugin.aws.s3.Upload`, `io.kestra.plugin.jdbc.snowflake.Query`, `io.kestra.plugin.core.flow.WorkingDirectory`, `io.kestra.plugin.git.Clone`, `io.kestra.plugin.dbt.cli.DbtCLI`.
- We have added Retries in the API call tasks, with certain parameters, e.g. maximum time of attempting & interval between different attempts.
- The `ghcr.io/dbt-labs/dbt-snowflake:1.8.3` dbt image with the snowflake adapter is pulled when it is time for the dbt task.

## Documentation
- [Kestra installation](https://kestra.io/docs/installation/docker-compose)
- [Clone a Git repository in Kestra](https://kestra.io/plugins/plugin-git/tasks/io.kestra.plugin.git.clone)
- [Execute DBT commands in Kestra](https://kestra.io/plugins/plugin-dbt/tasks/cli/io.kestra.plugin.dbt.cli.dbtcli)
- [Kestra Working Directory](https://kestra.io/docs/workflow-components/tasks/scripts/working-directory)
- [Providing secrets in Kestra flows](https://kestra.io/docs/concepts/secret)
- [Triggers in Kestra flows](https://kestra.io/docs/tutorial/triggers)
- [CI/CD in Kestra with Github Actions](https://kestra.io/docs/version-control-cicd/cicd/github-action)
- [Retries in Kestra flows](https://kestra.io/docs/workflow-components/retries)
- [Guide to connecting Snowflake with S3](https://snowflakewiki.medium.com/connecting-snowflake-to-aws-ef7b6de1d6aa)
- [Football-data API documentation](https://www.football-data.org/documentation/quickstart)