# Set up your registry credentials

Configure the plugin to authenticate to your container registry.

## Overview

Many container registries require authentication in order to push images, or even pull them.
The plugin reads your registry credentials from a `.netrc` file in your home directory.
Add a record into the `.netrc` file for each registry you use.
The plugin chooses the correct record based on the hostname of the registry's authentication server.

> For some registries, such as Docker Hub [(see example)](<doc:#Docker-Hub>), the authentication server hostname might not be the same as the registry hostname you use when pushing and pulling images.

The following example shows placeholder values for the registry `registry.example.com`:

```
machine registry.example.com
  login myuser
  password mypassword
```

The following examples show how to set up the plugin for some popular registry providers.

### Docker Hub

> Don't use your Docker Hub account password to push and pull images.
> Create a Personal Access Token, which has restricted privileges, for each integration you use.
> By using separate tokens, you can monitor them independently and revoke one at any time.
To create a `.netrc` entry for Docker Hub:

1. Log into Docker Hub and [generate a Personal Access Token](https://docs.docker.com/security/for-developers/access-tokens/) for Swift Container Plugin.

2. **Set the token's access permissions to *Read & Write*.**

3. Copy the token and add it, together with your Docker ID, to your `.netrc` file under the machine name `auth.docker.io`:

The final `.netrc` entry should be similar to this:

```
machine auth.docker.io
  login mydockerid
  password dckr_pat_B3FwrU...
```

### GitHub Container Registry

> GitHub Container Registry only supports authentication using a [Personal Access Token (classic)](https://docs.github.com/en/packages/working-with-a-github-packages-registry/working-with-the-container-registry#authenticating-to-the-container-registry).
> A fine-grained personal access token cannot be used.

To create a `.netrc` entry for Github Container Registry:

1. Log into GitHub and [generate a Personal Access Token (classic)](https://docs.github.com/en/authentication/keeping-your-account-and-data-secure/managing-your-personal-access-tokens#creating-a-personal-access-token-classic) for Swift Container Plugin.

2. **Select the *write:packages* scope.**

3. Copy the token and add it, together with your GitHub username, to your `.netrc` file:

The final `.netrc` entry should be similar to this:

```
machine ghcr.io
  login mygithubusername
  password ghp_fAOsWl...
```

### Amazon Elastic Container Registry

> Amazon Elastic Container Registry uses [short-lived authorization tokens](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html#registry-auth-token) which expire after 12 hours.
>
> To generate an ECR authentication token, you must [first install the AWS CLI tools.](https://docs.aws.amazon.com/cli/latest/userguide/getting-started-install.html)

#### Using environment variables

Environment variables are a convenient way to store short-lived credentials.

1. **Remove any existing ECR credentials from your `.netrc` file.**   If any entries in `.netrc` match your ECR registry hostname, these will be used in preference to the credentials in environment variables.

2. Set the ECR username.

    **The login name must be `AWS`**.

    ```
    export CONTAINERTOOL_DEFAULT_USERNAME=AWS
    ```

3. Use the `aws` CLI tool to [generate an authentication token](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html#registry-auth-token).
You'll need to know the name of the [AWS region](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html) in which your registry is hosted.
Registries in different AWS regions are separate and require different authentication tokens.

    For example, the following command generates a token for ECR in the `us-west-2` region:

    ```
    export CONTAINERTOOL_DEFAULT_PASSWORD=$(aws ecr get-login-password --region us-west-2)
    ```

#### Using the netrc file

To create a `.netrc` entry for Amazon Elastic Container Registry:

1. Use the `aws` CLI tool to [generate an authentication token](https://docs.aws.amazon.com/AmazonECR/latest/userguide/registry_auth.html#registry-auth-token).
You'll need to know the name of the [AWS region](https://docs.aws.amazon.com/global-infrastructure/latest/regions/aws-regions.html) in which your registry is hosted.
Registries in different AWS regions are separate and require different authentication tokens.

    For example, the following command generates a token for ECR in the `us-west-2` region:
    ```
    aws ecr get-login-password --region us-west-2
    ```

2. Copy the token and add it to your `.netrc` file.
    * The format of the machine name is:

        ```
        <aws_account_id>.dkr.ecr.<region>.amazonaws.com
        ```

      You can [find your AWS account ID](https://docs.aws.amazon.com/accounts/latest/reference/manage-acct-identifiers.html) in the AWS Management Console or by running the following command:
        ```
        aws sts get-caller-identity \
            --query Account \
            --output text
        ```
    * **The login name must be `AWS`**.
    * The token is a large encoded string.
        It must appear in the `.netrc` file as a single line, with no breaks.

The final `.netrc` entry should be similar to this:

```
machine 123456789012.dkr.ecr.us-west-2.amazonaws.com
  login AWS
  password eyJwYXlsb2FkIj...
```
