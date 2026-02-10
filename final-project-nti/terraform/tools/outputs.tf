output "nlb_target_group_arn" {
  description = "ARN of the NLB Target Group from Infrastructure state"
  value       = data.terraform_remote_state.infrastructure.outputs.nlb_target_group_arn
}
