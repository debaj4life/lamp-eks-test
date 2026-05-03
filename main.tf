module "network" { 
  source              = "./modules/network"
  vpc_cidr            = "10.0.0.0/16"
  vpc_name            = "global-vpc"
  public_subnet_cidrs = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
  private_subnet_cidrs = ["10.0.4.0/24", "10.0.5.0/24", "10.0.6.0/24"]
  availability_zones = ["eu-west-2a", "eu-west-2b", "eu-west-2c"]
}

module "security_groups" {
  source = "./modules/security-groups"
  vpc_id = module.network.vpc_id
  vpc_cidr = "10.0.0.0/16"
}

module "rds" {
  source            = "./modules/rds"
  username          = var.db_username
  name              = var.db_name
  db_subnet_ids     = module.network.private_subnet_ids
  security_group_id = module.security_groups.db_security_group_id
  allocated_storage       = var.allocated_storage
  instance_class          = var.instance_class
  skip_final_snapshot     = var.skip_final_snapshot
}

module "eks" {
  source             = "./modules/eks"
  subnet_ids         = module.network.public_subnet_ids
  node_subnet_ids    = module.network.private_subnet_ids
  node_instance_type = "t3.micro"
  node_desired_size  = 2
  node_min_size      = 2
  node_max_size      = 2
}