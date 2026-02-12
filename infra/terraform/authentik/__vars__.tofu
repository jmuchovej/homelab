variable "domain" {
  description = "Domain name"
  type = object({
    root = string
    dc   = string
    cf   = any
  })
}

variable "datacenter" {
  description = "Datacenter name"
  type        = string
}
