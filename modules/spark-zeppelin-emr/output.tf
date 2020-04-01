output "spark-zepplein-emr-cluster" {
  value = {
    id: aws_emr_cluster.this.id,
    name: aws_emr_cluster.this.name
  }
}