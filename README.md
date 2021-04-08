# POC - IaaC 

This is a IaaC in order to spin infrastructure for a POC.

## Installation
Please make sure that you have [terraform](https://www.terraform.io/downloads.html) installed. 
Please craete a database manaully or using a scrips in /poc-infrastructure/database/

Below is the folder structure of this code.

```bash
├── LICENSE
├── README.md
├── cicd
├── database
│   └── dev
│       └── main.tf
├── environments
│   └── dev
│       ├── dev.env.tfvars
│       ├── main.tf
│       ├── outputs.tf
│       ├── providers.tf
│       └── variables.tf
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
