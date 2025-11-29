//Variables comunes
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

//Variables de configuración S3
variable "enable_versioning" {
  description = "Habilitar versionado en el bucket S3"
  type        = bool
  default     = true
}

variable "lifecycle_rules_enabled" {
  description = "Habilitar reglas de ciclo de vida en el bucket S3"
  type        = bool
  default     = true
}

variable "days_until_transition" {
  description = "Número de días hasta la transición a almacenamiento Glacier"
  type        = number
  default     = 90
}

variable "days_to_glacier" {
  description = "Número de días para mantener los objetos en almacenamiento Glacier"
  type        = number
  default     = 180
}

variable "days_to_expire" {
  description = "Días para eliminar objetos (0 = nunca)"
  type        = number
  default     = 0
}

variable "days_to_transition_ia" {
  description = "Días para mover a Infrequent Access"
  type        = number
  default     = 90
}

variable "enable_encryption" {
  description = "Habilitar encriptación en reposo"
  type        = bool
  default     = true
}

variable "kms_key_id" {
  description = "ID de la clave KMS para encriptación (si enable_encryption es true)"
  type        = string
  default     = null
}

variable "block_public_access" {
  description = "Bloquea todo el acceso publico"
  type        = bool
  default     = true
}

variable "enable_access_logging" {
  description = "Habilitar logs de acceso"
  type        = bool
  default     = true
}