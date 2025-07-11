variable "redirect_hostnames" {
  description = "Name of application"
  type        = list(string)
  default     = ["", "www"]
}

variable "redirect_to" {
  description = "Hostname where to redirect HTTP(S) requests to"
  type        = string
}

variable "zone_id" {
  description = "Zone ID where the redirect_hostnames records will be created"
  type        = string
}
