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
variable "network_id" {
  description = "Network"
}
variable "subnet_id" {
  description = "Subnet name"
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
variable "count_of_instances" {
  description = "Count of instances"
  default     = 2
}
variable "enable_provision" {
  description = "Enable provision"
  default     = true
}
variable "token" {
  description = "<OAuth>"
}
variable "service_account_id" {
  description = "<service_account_id>"
}
variable "cores" {
  description = "VM cores"
  default     = 2
}
variable "memory" {
  description = "VM memory"
  default     = 8
}
variable "disk" {
  description = "Disk size"
  default     = 93
}
variable "count_of_workers" {
  description = "count_of_workers"
  default     = 1
}
variable "cluster_name" {
  description = "k8s cluster name"
  default     = "k8s_4otus"
}
variable "k8s_version" {
  description = "k8s cluster version"
  default     = "1.23"
}


