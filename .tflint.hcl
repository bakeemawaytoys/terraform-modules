config {
    # Inspecting module calls requires initialization of TF prior to running TFLint
    # The TFLint docker image doesn't have Terraform installed.  Working around this
    # in Gitlab CI is a pain so disable the check.  If calling out to child modules
    # because commonplace in this project, then it is worth revisiting this settings.
    # As of the writing of this comment, only one module does.
    module = false
}

plugin "aws" {
    enabled = true
    version = "0.27.0"
    source  = "github.com/terraform-linters/tflint-ruleset-aws"
}


rule "terraform_comment_syntax" {
    enabled = true
}

rule "terraform_documented_outputs" {
    enabled = true
}

rule "terraform_documented_variables" {
    enabled = true
}

rule "terraform_naming_convention" {
    enabled = true
}

rule "terraform_standard_module_structure" {
    enabled = true
}

