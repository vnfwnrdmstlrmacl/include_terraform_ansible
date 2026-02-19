# 1. DMS 복제 인스턴스 보안 그룹
resource "aws_security_group" "dms_sg" {
  name        = "${var.project_name}-dms-sg"
  vpc_id      = var.vpc_id

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }

  tags = { Name = "${var.project_name}-dms-sg" }
}

# 2. DMS 서브넷 그룹
resource "aws_dms_replication_subnet_group" "main" {
  replication_subnet_group_description = "DMS subnet group"
  replication_subnet_group_id          = "${var.project_name}-dms-subnet-group"
  subnet_ids                           = var.subnet_ids
}

# 3. DMS 복제 인스턴스 생성
resource "aws_dms_replication_instance" "main" {
  replication_instance_class   = var.dms_instance_class
  replication_instance_id      = "${var.project_name}-reproduction-instance"
  replication_subnet_group_id  = aws_dms_replication_subnet_group.main.id
  vpc_security_group_ids       = [aws_security_group.dms_sg.id]
  multi_az                     = false
  apply_immediately            = true
}

# 4. 소스 엔드포인트 (온프레미스 PostgreSQL)
resource "aws_dms_endpoint" "source" {
  endpoint_id                 = "onprem-source"
  endpoint_type               = "source"
  engine_name                 = "postgres"
  server_name                 = var.onprem_db_tailscale_ip # 온프레미스 Tailscale IP 사용
  port                        = 5432
  database_name               = "appdb"
  username                    = "postgres"
  password                    = var.db_password
  ssl_mode                    = "none"
}

# 5. 타겟 엔드포인트 (AWS RDS)
resource "aws_dms_endpoint" "target" {
  endpoint_id                 = "rds-target"
  endpoint_type               = "target"
  engine_name                 = "postgres"
  server_name                 = var.rds_endpoint
  port                        = 5432
  database_name               = "appdb"
  username                    = "postgres"
  password                    = var.db_password
  ssl_mode                    = "none"
}

# 6. [신규 추가] DMS 복제 태스크
# 이 리소스가 있어야 실제로 데이터 복제가 시작됩니다.
resource "aws_dms_replication_task" "main" {
  migration_type           = "full-load"
  replication_instance_arn = aws_dms_replication_instance.main.replication_instance_arn
  replication_task_id      = "${var.project_name}-migration-task"
  source_endpoint_arn      = aws_dms_endpoint.source.endpoint_arn
  target_endpoint_arn      = aws_dms_endpoint.target.endpoint_arn

  # 소스(온프레)의 모든 테이블을 포함하는 매핑 설정
  table_mappings = jsonencode({
    rules = [{
      rule-type = "selection", rule-id = "1", rule-name = "1"
      object-locator = { schema-name = "public", table-name = "%" }
      rule-action = "include"
    }]
  })

  replication_task_settings = jsonencode({
    TargetMetadata = {
      # 온프레미스의 테이블 구조(Schema)를 RDS에 자동으로 생성합니다.
      TargetTablePrepMode = "DROP_AND_CREATE"
    }
  })

  tags = { Name = "${var.project_name}-migration-task" }
}
