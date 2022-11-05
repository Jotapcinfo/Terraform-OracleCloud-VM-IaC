variable "compartment_ocid" {}
variable "region" {}
variable "tenancy_ocid" {}
variable "user_ocid" {}
variable "fingerprint" {}
variable "private_key" {}
variable "ssh_public_key" {}

provider "oci" {
    tenancy_ocid = var.tenancy_ocid
    user_ocid = var.user_ocid
    fingerprint = var.fingerprint
    private_key = var.private_key
    region = var.region
}

variable "ad_region_mapping" {
    type = map(string)
    
    default = {  
        sa-saopaulo-1 = 1
    }
}

variable "images" {
    type = map(string)
    
    # Oracle-provided image "Oracle-Autonomous-Linux-7.9-2022.08.24-0"
    default = {
    sa-saopaulo-1 = "ocid1.image.oc1.sa-saopaulo-1.aaaaaaaar22c3rg6djcwxsdw3o32h2moegl5y7mnmbtcakvgq2oskhk6uxsa"
    }
}

data "oci_identity_availability_domain" "ad" {
    compartment_id = var.tenancy_ocid
    ad_number = var.ad_region_mapping[var.region]
}

resource "oci_core_virtual_network" "tcb_vcn" {
    cidr_block = "10.1.0.0/16"
    compartment_id = var.compartment_ocid
    display_name  = "tcbVCN"
    dns_label = "tcbvcn"
}

resource "oci_core_subnet" "tcb_subnet" {
    cidr_block = "10.1.20.0/24"
    display_name = "tcbSubnet"
    dns_label = "tcbsubnet"
    security_list_ids  = [oci_core_security_list.tcb_security_list.id]
    compartment_id  = var.compartment_ocid
    route_table_id = oci_core_route_table.tcb_route_table.id
    vcn_id = oci_core_virtual_network.tcb_vcn.id
    dhcp_options_id = oci_core_virtual_network.tcb_vcn.default_dhcp_options_id
}

resource "oci_core_internet_gateway" "tcb_internet_gateway" {
    compartment_id = var.compartment_ocid
    display_name = "tcbIG"
    vcn_id = oci_core_virtual_network.tcb_vcn.id
}

resource "oci_core_route_table" "tcb_route_table" {
    compartment_id = var.compartment_ocid
    display_name = "tcbRouteTable"
    vcn_id = oci_core_virtual_network.tcb_vcn.id

route_rules {
    destination = "0.0.0.0/0"
    destination_type = "cidr_block"
    network_entity_id = oci_core_internet_gateway.tcb_internet_gateway.id
  }
}

resource "oci_core_security_list" "tcb_security_list" {
    compartment_id = var.compartment_ocid
    vcn_id = oci_core_virtual_network.tcb_vcn.id
    display_name = "tcbSecurityList"

egress_security_rules {
    protocol = "6"
    destination = "0.0.0.0/0"
}

ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0" 

    tcp_options {
        max = 22
        min = 22
    }
}

ingress_security_rules {
    protocol = "6"
    source = "0.0.0.0/0" 

    tcp_options {
        max = 80
        min = 80
    }
  } 
}

resource "oci_core_instance" "webserver" {
    availability_domain = data.oci_identity_availability_domain.ad.name
    compartment_id = var.compartment_ocid
    display_name = "cloudTerraformAulaOCI"
    shape "VM.Standard.E2.1.Micro"

    create_vnic_details {
        subnet_id = oci_core_subnet.tcb_subnet.id
        display_name = "primaryvnic"
        assign_public_ip = true
        hostname_label = "cloudTerraformAulaOCI"
    }

    source_details {
        source_type = "image" 
        source_id = var.images[var.region]
    }
     
    metadata = {
        ssh_authorized_keys = var.ssh_public_key
    } 
}
