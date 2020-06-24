## Getting started

On the provisioner

* Copy image.img.tgz to the web root of nginx

* Then run:

```sh
./create_images.sh
```

* Then create the ubuntu.tmpl template with tink-cli

```
tink template create -n 'ubuntu' -p /tmp/ubuntu.tmpl
```

* Now create the hardware entry

```
tink hardware push --file /tmp/hw1.json 
```
* Now create a workflow for the entry with the template ID

```
# See the output from Terraform
export MAC="08:00:27:00:00:01"

# See tink template list
export TEMPLATE_ID="93de9281-d28a-4e9e-b8d8-8162d197b15f"
tink workflow create -t "$TEMPLATE_ID" -r '{"device_1": "'$MAC'"}'
```

* Boot up the worker
