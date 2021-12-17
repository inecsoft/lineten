
resource "kubernetes_service_account" "prod_lineten_api" {
  metadata {
    name      = "prod-lineten-api"
    namespace = "lineten"
  }
  automount_service_account_token = true
}

resource "kubernetes_cluster_role_binding" "prod_lineten_api" {
  metadata {
    name = "eks:podsecuritypolicy:privileged:lineten:prod_lineten_api"
    labels = {
      "eks.amazonaws.com/component"   = "pod-security-policy"
      "kubernetes.io/cluster-service" = "true"
    }
    annotations = {
      "kubernetes.io/description" = "Allow lineten prod_lineten_api service account to create privileged pods."
    }
  }
  subject {
    kind      = "ServiceAccount"
    name      = "prod-lineten-api"
    namespace = "lineten"
  }
  role_ref {
    api_group = "rbac.authorization.k8s.io"
    kind      = "ClusterRole"
    name      = "eks:podsecuritypolicy:restricted"
  }
}

resource "kubernetes_service" "lineten_api_prod_svc" {
  metadata {
    name      = "lineten-api-prod-svc"
    namespace = "lineten"

    annotations = {
      "alb.ingress.kubernetes.io/healthcheck-path" = "/"
    }

    labels = {
      app = "lineten-api-prod"
    }
  }

  spec {
    port {
      protocol    = "TCP"
      port        = 3000
      target_port = "3000"
    }

    selector = {
      app  = "lineten-api-prod"
      type = "web"
    }

    type = "NodePort"
  }
}

resource "kubernetes_deployment" "lineten_api_prod" {
  metadata {
    name      = "lineten-api-prod"
    namespace = "lineten"

    labels = {
      app = "lineten-api-prod"

      type = "web"
    }
  }

  wait_for_rollout = true

  spec {
    replicas = 1

    selector {
      match_labels = {
        app  = "lineten-api-prod"
        type = "web"
      }
    }

    template {
      metadata {
        labels = {
          app = "lineten-api-prod"

          type = "web"
        }
      }

      spec {
        container {
          name  = "lineten-api-prod"
          image = "050124427385.dkr.ecr.eu-west-1.amazonaws.com/lineten:0.0"

          port {
            container_port = 3000
          }

          env {
            name  = "SPACY_MODEL"
            value = "/usr/src/model"
          }
		  
         env {
            name = "OAUTH_CLIENT_SECRET"

            value_from {
              secret_key_ref {
                name = "lineten-prod-oauth2-microsoft"
                key  = "client_secret"
              }
            }
          }

          resources {
            limits {
              cpu    = "600m"
              memory = "1400Mi"
            }
            requests {
              cpu    = "400m"
              memory = "1200Mi"
            }
          }

          liveness_probe {
            http_get {
              path = "/"
              port = "3000"
            }

            initial_delay_seconds = 60
            period_seconds        = 15
            timeout_seconds       = 10
          }

          readiness_probe {
            http_get {
              path = "/"
              port = "3000"
            }

            initial_delay_seconds = 30
            period_seconds        = 5
            success_threshold     = 3
            timeout_seconds       = 10
          }
          image_pull_policy        = "Always"
          termination_message_path = "/dev/termination-log"
        }
        restart_policy                   = "Always"
        termination_grace_period_seconds = 60
        dns_policy                       = "ClusterFirst"
        service_account_name             = "prod-lineten-api"
        automount_service_account_token  = true
        node_selector                    = { "deployment_env" = "prod" }
      }
    }
  }
  lifecycle {
    ignore_changes = [spec[0].template[0].spec[0].container[0].image]
  }
}

resource "kubernetes_secret" "lineten_prod_oauth2_microsoft" {
  metadata {
    name      = "lineten-prod-oauth2-microsoft"
    namespace = "lineten"
  }

  data = {
    client_secret         = data.aws_ssm_parameter.lineten_prod_client_secret.value
    service_user_password = data.aws_ssm_parameter.lineten_prod_service_user_password.value
  }

  type = "Opaque"
}

resource "kubernetes_ingress" "prod_lineten_alb" {
  metadata {
    name      = "prod-lineten-alb"
    namespace = "lineten"

    annotations = {
      // Cert annotation must be left on to known and available cert in ACM otherwise SSL can be removed in situations where a mactching cert can not be found !!
      "alb.ingress.kubernetes.io/certificate-arn"          = data.aws_acm_certificate.eks_default_cert.arn
      "alb.ingress.kubernetes.io/load-balancer-attributes" = <<ATTR
      deletion_protection.enabled=true, 
      routing.http.drop_invalid_header_fields.enabled=true,
      routing.http2.enabled=true,
      access_logs.s3.enabled=true,
      access_logs.s3.bucket=${replace(var.cluster_name, "_", "-")}-aws-alb-accesslogs,access_logs.s3.prefix=prod/prod-lineten-alb
      ATTR           
      "alb.ingress.kubernetes.io/listen-ports"             = "[{\"HTTP\": 80}, {\"HTTPS\": 443}]"
      "alb.ingress.kubernetes.io/ssl-redirect"             = "443"
      "alb.ingress.kubernetes.io/scheme"                   = "internet-facing"
      "alb.ingress.kubernetes.io/success-codes"            = "200,302"
      "alb.ingress.kubernetes.io/healthcheck-path"         = "/"
      "alb.ingress.kubernetes.io/tags"                     = "Environment=prod,Project=lineten"
      "external-dns.alpha.kubernetes.io/hostname"          = var.cluster_name
      "kubernetes.io/ingress.class"                        = "alb"
      "alb.ingress.kubernetes.io/inbound-cidrs"            = "0.0.0.0/0" #"${var.home_whitelist}"
    }
  }

  spec {


    rule {
      host = "lineten-api-prod.${replace(var.cluster_name, "_", "-")}.lineten.com"

      http {
        path {
          path = "/*"

          backend {
            service_name = "lineten-api-prod-svc"
            service_port = "3000"
          }
        }
      }
    }
  }
}

