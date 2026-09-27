# DNS and TLS for the billing API. State lives in Riverton's own backend;
# the prod values file is kept by Riverton IT and is not in this repository.

variable "prod_hostname" {
  type        = string
  description = "Public hostname of the production billing API"
}

variable "staging_hostname" {
  type    = string
  default = "billing-staging.riverton.example.com"
}

resource "kubernetes_ingress_v1" "billing" {
  metadata { name = "billing-api" }
  spec {
    rule {
      host = var.prod_hostname
      http {
        path {
          path = "/"
          backend {
            service {
              name = "billing-api"
              port { number = 80 }
            }
          }
        }
      }
    }
  }
}
