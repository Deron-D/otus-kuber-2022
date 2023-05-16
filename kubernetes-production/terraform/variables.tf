variable "cloud_id" {
  description = "Cloud"
}
variable "folder_id" {
  description = "Folder"
}
variable "zone" {
  description = "Zone"
  # Значение по умолчанию
  default = "ru-central1-a"
}
variable "public_key_path" {
  # Описание переменной
  description = "Path to the public key used for ssh access"
}
# variable image_id {
#   description = "Disk image"
# }
variable "subnet_id" {
  description = "Subnet"
}
variable "service_account_key_file" {
  description = "key.json"
}
variable "private_key_path" {
  description = "Path to private key used for ssh access"
}
variable "region_id" {
  description = "ID of the availability zone where the network load balancer resides"
  default     = "ru-central1"
}
variable "instance_count" {
  description = "Count of instances"
  default     = 1
}
variable "enable_provision" {
  description = "Enable provision"
  default     = true
}
variable "token" {
  description = "<OAuth>"
}
variable "ssh_username" {
  description = "SSH username"
}