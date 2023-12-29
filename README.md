# Terraform Modules

## Overview

A monorepo containing custom Terraform [child modules](https://www.terraform.io/language/modules#child-modules).  The modules were developed either wholely or primarily by me in a professional capacity over the past few years.  They've been modified to allow them to be made public.  The Git history has been squashed for the same reason.  The entries in the modules' CHANGELOG files have not been squashed to preserve some form of history.  The module versions mentioned in the CHANGELOG files, and their corresponding Git tags, no longer exist due to the Git history squash.

The modules are primarily for managing AWS resources and Kubernetes resources (running on EKS) with some Hashicorp Vault resources thrown in for good measure.  The modules resources were used to manage applications stored in a self-hosted private Gitlab instance.  The applications were deployed using Gitlab CI/CD pipelines.  The pipelines were a heavily customized version of Gitlab's built-in Auto DevOps pipeline.  The Gitlab pipeline definition for this project has been preserved for posterity.  I hope to convert it to Github actions in the near future.

When some of these modules were created, they had to be designed to accommodate existing resources that were created outside of Terraform.  As a result, their naming conventions and design decisions don't always make sense anymore.  Those resources were often created by custom Ansible roles and/or playbooks.  The roles and/or playbooks were used as a model for the initial implementation of the modules.

Every section in this README file after this one is from the project's original README file.

## Using a Module

The modules in this project can be called by specifying the [module's source](https://www.terraform.io/language/modules/sources) as a Git URL.  Terraform supports both [SSH and HTTPS Git URLs](https://www.terraform.io/language/modules/sources#generic-git-repository).  Every time a version of a module is released, a Git tag is created in this repository.  A tag should always be [included in the Git URL](https://www.terraform.io/language/modules/sources#selecting-a-revision) to pin the module to a specific version.  Doing so will ensure consistent, predictable, and repeatable Terraform runs.  The tags follow the naming convention of `<module name>-v<version>` where the version is a [semantic version number](https://semver.org/) controlled by the VERSION file in every module.  Every new version of a module also creates a Gitlab release.

## Module Development

### Project Setup

Review the following sections prior to making any changes to the project to ensure a consistent development environment among developers.

#### Editor

An [EditorConfig](https://editorconfig.org/) file is included in this template to help maintain consistent formatting.  Be sure to install EditorConfig if you haven't already done so.

#### Pre-commit hooks

Included in this template is a configuration file for Git [pre-commit framework](https://pre-commit.com/).  It contains [hooks maintained by Gruntworks](https://github.com/gruntwork-io/pre-commit) that are relevant to Terraform development.

1. Install Terraform 1.6
1. Install [tflint](https://github.com/terraform-linters/tflint)
1. Install [terraform-docs](https://terraform-docs.io/user-guide/installation/)
1. Run `pre-commit install` to install the hooks
1. (Optional) verify the hooks are working by running `pre-commit run --all-files`

### Creating a New Module

If you haven't already done so, review Hashicorp's documentation on module creation and development.

* [Module Development](https://www.terraform.io/language/modules/develop).
* [Module Creation Tutorial](https://learn.hashicorp.com/tutorials/terraform/module-create?in=terraform/modules)
* [Module Creation Patterns](https://learn.hashicorp.com/tutorials/terraform/pattern-module-creation?in=terraform/modules)
* [Best Practices for Provider Version Constraints](https://www.terraform.io/language/providers/requirements#best-practices-for-provider-versions)
* [Input Variable Documentation](https://www.terraform.io/language/values/variables)
* [Output Value Documentation](https://www.terraform.io/language/values/outputs)

The workflow for creating a new module is as follows.

1. Create a new Git branch.
1. Create a new directory in the project.  The name of the directory corresponds to the name of the module.  **Modules names must be kebab case** to be consistent with [the naming convention of public Terraform modules](https://www.terraform.io/registry/modules/publish#requirements).
1. Create a _terraform-docs_ pre-commit hook for the module in [_.pre-commit-config.yaml_](.pre-commit-config.yaml) to automatically update the module's _README.md_ file on commit.  To create the hook, add a new entry to the list of hooks for the <https://github.com/terraform-docs/terraform-docs> repo. For example, if the new module is named _my-new-module_, then the new hook will look like the following YAML snippet.

    ```yaml
      - id: terraform-docs-system
        name: "Run terraform-docs for my-new-module"
        files: "^my-new-module/.+"
        args: ["my-new-module"]
    ```

1. Copy the contents of the [templates/module](templates/module) directory into the new directory.  The template contains all of the necessary files for [the standard module structure](https://www.terraform.io/language/modules/develop/structure) recommended by Hashicorp.
1. Implement and test the new module.
1. Populate the module's _README.md_ file with useful information.  Additionally, run _terraform-docs_ to add generated documentation to the _README.md_ file.  For example, if the new module is named _my-new-module_, then the _terraform-docs_ command to run from the project's root directory is the following.

    ```shell
    terraform-docs my-new-module
    ```

1. Add the new module to the [_.gitlab-ci.yml_](.gitlab-ci.yml) file by creating a new job that extends the `.module-build` job.  For example, if the new module is named _my-new-module_, then the new job will look like the following.

    ```yaml
    my-new-module:
        extends: .module-build
    ```

1. Create a merge request
1. Once the merge request has been reviewed and the CI/CD pipeline success, merge the branch.
1. A new pipeline will trigger once the branch has been merged.  The new pipeline generates a new tag for the module as well as a Gitlab release.
1. Use the new module in other projects.

### Modifying a Module

The workflow for modifying a module is as follows.

1. Create a new Git branch.
1. Update the module and test the changes.
1. Update the module's _README.md_ file, if necessary.
1. Add a new entry to the module's CHANGELOG.md file under the _Unreleased_ header.  Refer to the [Keep A Changelog](https://keepachangelog.com/en/1.0.0/) documentation to determine what to add to the changelog.
1. Create a merge request
1. Add a link to the merge request to the entries added to the CHANGELOG.md file.
1. Once the merge request has been approved and the CI/CD pipeline success, merge the branch.

### Releasing a New Module Version

1. Increment the module's version number in its _VERSION_ file if code changes were made.  Refer to the [Semantic Versioning documentation](https://semver.org/#summary) to determine which component of the version number to increment.
1. Add a new section to the module's CHANGELOG file for the new version.  All content that is currently under the _Unreleased_ header must be moved to the new section.
1. Create a merge request
1. Once the merge request has been approved and the CI/CD pipeline success, merge the branch.
1. A new pipeline will trigger once the branch has been merged.  The new pipeline generates a new tag for the module as well as a Gitlab release.
1. Upgrade the module in dependent projects by changing the value of the Git tag in the source attribute of every module call.

### Module Testing

Testing a module can be done locally on a developer's machine by using a second Terraform project.  In the second project, set the source of the attribute in the module call to the absolute file path of the module's directory in this project.  If the second project already calls the module and it is under version control, the source attribute can be overridden by using an [override file](https://www.terraform.io/language/files/override).  Override files are ignored by Git but the values in them take precedence over the values defined in other Terraform files.  This ensures that changes made for testing are not accidentally committed to Git.

The workflow for this testing strategy is as follows.

1. Add the file _override.tf_ to the root of the second project.
1. Add `override.tf` to the second project's _.gitignore_ file.
1. In the override file, make a module call with the same name as the existing module call.
1. Set the source attribute of the module call in the override file to the absolute file path of the module's directory in this project.
1. Run `terraform get` in the second project to install the new module source.
1. Add or modify module variables as necessary in the override file.
1. Run `terraform plan` in the second project and make changes to the module source if necessary. Repeat this step until the results of the plan are correct.
