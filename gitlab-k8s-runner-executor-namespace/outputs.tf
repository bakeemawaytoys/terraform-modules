output "cluster_name" {
  description = "The name of the EKS cluster containing the namespace."
  value       = var.eks_cluster.cluster_name
}

output "distributed_cache_bucket" {
  description = <<-EOF
  An object containing the attributes of the S3 bucket the executors use as a distributed cache.  The IAM role has
  full permission to the objects in the bucket.  Can be used as the value of the `distributed_cache_bucket`
  variable in the gitlab-k8s-runner-executor module.
  EOF
  value = merge(
    var.distributed_cache_bucket,
    {
      # Add "name" as an alias to bucket so that this module can be used as the value of the distributed_cache_bucket in the gitlab-k8s-runner-executor
      name = var.distributed_cache_bucket.bucket
    }
  )
}

output "iam_role_arn" {
  description = "The ARN of the IAM role the executors are allowed to assume using the EKS IAM Roles for Service Accounts feature."
  value       = module.iam_role.arn
}

output "iam_role_name" {
  description = "The name of the IAM role the executors are allowed to assume using the EKS IAM Roles for Service Accounts feature."
  value       = module.iam_role.name
}

output "name" {
  description = "The name of the namespace."
  value       = kubernetes_namespace_v1.this.metadata[0].name
}
