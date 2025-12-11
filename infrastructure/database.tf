resource "aws_db_instance" "leaky_db" {
  identifier           = "leaky-shop-db"
  allocated_storage    = 20
  storage_type         = "gp2"
  engine               = "postgres"
  engine_version       = "11.22" # MISCONFIG: EOL version
  instance_class       = "db.t3.micro"
  db_name              = "shopdb"
  
  # MISCONFIG: Hardcoded & Unencrypted
  username             = "admin"
  password             = "password123" 
  storage_encrypted    = false
  
  # MISCONFIG: Publicly Accessible
  publicly_accessible  = true
  
  backup_retention_period = 0
  skip_final_snapshot     = true
  
  vpc_security_group_ids = [aws_security_group.allow_all.id]
  db_subnet_group_name   = aws_db_subnet_group.leaky_db_subnet.name
}

resource "aws_db_subnet_group" "leaky_db_subnet" {
  name       = "leaky-db-subnet-group"
  subnet_ids = [aws_subnet.public_subnet_1.id, aws_subnet.public_subnet_2.id]
}