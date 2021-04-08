# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Environment specific variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

variable "environment" {
}

variable "secretManagerArn" {
}

variable "kmsArn" {
}

variable "appserver_cluster_minimum_size" {
  default = 1
}

variable "appserver_cluster_maximum_size" {
  default = 1
}

variable "appserver_cluster_desired_capacity" {
  default = 1
}

variable "appserver_tasks_desired_count" {
  default = 1
}

variable "app_server_cluster_instance_type" {
  default = "t2.micro"
}

variable "webserver_cluster_minimum_size" {
  default = 1
}

variable "webserver_cluster_maximum_size" {
  default = 1
}

variable "webserver_cluster_desired_capacity" {
  default = 1
}

variable "webserver_tasks_desired_count" {
  default = 1
}

variable "webserver_cluster_instance_type" {
  default = "t2.micro"
}

variable "cidr_first_two_blocks" {
  default = "10.0"
}



# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Global variables
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

variable "region" {
  default = "eu-west-2"
}

variable "project" {
  default = "poc"
}

variable "hostedZoneID" {
  default = "Z1031817MGWHDOQFVVVI"
}

variable "terraform_aws_modules_version" {
  default = "2.77.0"
}

variable "infrablocks_ecs_service_modules_version" {
  default = "3.4.0"
}

variable "ecs_service_ordered_placement_strategy" {
  default = "random"
}


