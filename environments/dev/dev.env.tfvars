# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #
# Environment specific variable values
# # # # # # # # # # # # # # # # # # # # # # # # # # # # # #

environment = "dev"

secretManagerArn = "arn:aws:secretsmanager:eu-west-2:003191751804:secret:proddb-aJP3NG"

kmsArn = "arn:aws:kms:eu-west-2:003191751804:key/b7210d76-0ca6-49ce-9fe4-a0f7694b7dcf"

appserver_cluster_minimum_size = 3

appserver_cluster_maximum_size = 3

appserver_cluster_desired_capacity = 3

appserver_tasks_desired_count = 3

app_server_cluster_instance_type = "t2.micro"

webserver_cluster_minimum_size = 3

webserver_cluster_maximum_size = 3

webserver_cluster_desired_capacity = 3

webserver_tasks_desired_count = 3

webserver_cluster_instance_type = "t2.micro"

cidr_first_two_blocks = "10.0"