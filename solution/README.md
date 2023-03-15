# Challenge solution

## Assignment 1

### Notes
- To satisfy case B, we implemented a L@E function to rewrite requests from `/devops-folder/` to `/`, as well as append `index.html` to requests with URIs ending with `/`.

- To satisfy case B.1, we implemented a CloudFront Function to copy the host header into x-host header and used that in the cache policy. This is because the host header isn't supported in cache policy with S3 origins ([reference](https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/header-caching.html#header-caching-web-selecting))

### How to run?

```shell
terraform init

terraform apply
```

Follow the link in the output for the distribution domain

## Assignment 2

Implemented using basic shell commands (cut/sort/uniq/sed/head)

### How to run?

```shell
./count logfile
```