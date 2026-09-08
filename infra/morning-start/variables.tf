variable "subscription_id" {
  type        = string
  description = "Subscription containing the two existing SIFAP environments."
}
variable "automation_resource_group" {
  type        = string
  description = "Resource group of the existing shared Automation account."
  default     = "sifap-lab-rg-eus2"
}
variable "automation_account_name" {
  type        = string
  description = "Existing managed-identity Automation account; never recreate the live lab."
  default     = "sifap-lab-aa-watchdog-eus2"
}
variable "modern_resource_group" {
  type        = string
  description = "Resource group of the existing modern environment."
  default     = "sifap-modern-rg-eus2"
}
variable "owner" {
  type        = string
  description = "Owner tag on the scheduled operations resources."
  default     = "workshop-gbb"
}
variable "location" {
  type        = string
  description = "Region of the existing Automation account."
  default     = "eastus2"
}
