# __lineten__

***

***
__Build__
```
docker build -t lineten .
```
__Run the app__
```
docker run  -it -d -p 3000:3000 --name lineten lineten
```
__Test__
```
curl localhost:3000
```
__Delete container__
```
docker rm lineten; docker rmi lineten
```

***
### __lineten app to postgres container__
```
docker-compose up --build
```
```
docker-compose up -d
```

***

#### Run the aws configure command to set your access and secret keys
```
aws configure
```
#### Rename the terraform.tfvars.example file to terraform.tfvars and change the region
#### to your desired region

#### Initialize the terraform configuration
```
terraform init
terraform apply -target aws_s3_bucket.state_bucket --auto-approve
```
#### Plan the terraform deployment
```
terraform plan -out vpc.tfplan
```
#### Apply the deployment
```
terraform apply "vpc.tfplan"
```

***