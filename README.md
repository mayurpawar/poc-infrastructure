# POC - IaaC 

This is a IaaC in order to spin infrastructure for a POC.

## Installation

Make sure that you have [terraform](https://www.terraform.io/downloads.html) installed. 

Craete a database manaully or using a scrips in /poc-infrastructure/database/dev. If you create a dataase independently then keep credentials in AWS Secret Manager as we will be using it in our project. At the same time note down KMS key ARN along with AWS Secret Manager ARN. These two will go in environment variables file.

Make sure to use AWS credentials. Use your preferred way. You can update providers.tf file and add credentials for easy use. 

Below is the folder structure of this code.

```bash
.
├── LICENSE
├── README.md
├── cicd
├── database
│   └── dev
│       └── main.tf
├── environments
│   ├── dev
│   │   ├── dev.env.tfvars
│   │   ├── main.tf
│   │   ├── outputs.tf
│   │   ├── providers.tf
│   │   └── variables.tf
│   └── prod
│       ├── main.tf -> ../dev/main.tf
│       ├── outputs.tf -> ../dev/outputs.tf
│       ├── prod.env.tfvars
│       ├── providers.tf -> ../dev/providers.tf
│       └── variables.tf -> ../dev/variables.tf
└── modules

```

## Usage
Please update environment variables first in dev.env.tfvars.
```bash
cd ~/poc-infrastructure/environments/dev
tf init
tf apply --var-file dev.env.tfvars 
```

## Contributing
Pull requests are welcome. This code is for very specific purpose and is kept here for evaluation. 

This repository will be deleted in a week's time.

## License
[MIT](https://choosealicense.com/licenses/mit/)
