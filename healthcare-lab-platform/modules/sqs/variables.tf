# Variables comunes
variable "project_name" {
  description = "Nombre del proyecto"
  type        = string
}
variable "environment" {
  description = "Ambiente (dev, staging, prod)"
  type        = string
}
variable "owner" {
  description = "Dueño del proyecto"
  type        = string
}

// Configuración de la cola principal
variable "visibility_timeout_seconds" {
  description = "Tiempo que un mensaje permanece invisible después de ser leído"
  type        = number
  default     = 300  
}

variable "message_retention_seconds" {
  description = "Tiempo que SQS retiene un mensaje"
  type        = number
  default     = 1209600  # 14 días (máximo)
}

variable "max_message_size" {
  description = "Tamaño máximo del mensaje en bytes"
  type        = number
  default     = 262144  # 256 KB (máximo)
}

variable "delay_seconds" {
  description = "Delay antes de que el mensaje esté disponible"
  type        = number
  default     = 0  # Sin delay por defecto
}

variable "receive_wait_time_seconds" {
  description = "Long polling wait time"
  type        = number
  default     = 20  # 20 segundos 
}

# Dead Letter Queue
variable "max_receive_count" {
  description = "Número de intentos antes de ir a DLQ"
  type        = number
  default     = 3
}

variable "dlq_message_retention_seconds" {
  description = "Tiempo de retención en DLQ"
  type        = number
  default     = 1209600  # 14 días
}

# Encriptación
variable "enable_encryption" {
  description = "Habilitar encriptación en SQS"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "KMS key para encriptación (null = usa SQS managed key)"
  type        = string
  default     = null
}

# CloudWatch Alarms
variable "enable_cloudwatch_alarms" {
  description = "Crear alarmas de CloudWatch"
  type        = bool
  default     = true
}

variable "alarm_email" {
  description = "Email para recibir alarmas"
  type        = string
  default     = ""
}