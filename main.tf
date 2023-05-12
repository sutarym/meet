provider "aws" {
  region     = "ap-south-1"
  access_key = "AKIAXQM6UOUEN4AYOC5O"
  secret_key = "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"
}

# Create VPC
resource "aws_vpc" "my_vpc" {
  cidr_block = "10.0.0.0/16"

  tags = {
    Name = "My VPC"
  }
}

# Create private subnet
resource "aws_subnet" "my_subnet" {
  vpc_id     = aws_vpc.my_vpc.id
  cidr_block = "10.0.1.0/24"

  tags = {
    Name = "My Private Subnet"
  }
}

# Create NAT gateway
resource "aws_nat_gateway" "my_nat_gateway" {
  allocation_id = aws_eip.my_eip.id
  subnet_id     = aws_subnet.my_subnet.id

}

# Create EIP for NAT gateway
resource "aws_eip" "my_eip" {
  vpc = true
}

# Create routing table
resource "aws_route_table" "my_route_table" {
  vpc_id = aws_vpc.my_vpc.id

  route {
    cidr_block = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.my_nat_gateway.id
  }

  tags = {
    Name = "My Route Table"
  }
}

# Associate subnet with the routing table
resource "aws_route_table_association" "my_route_table_association" {
  subnet_id = aws_subnet.my_subnet.id
  route_table_id = aws_route_table.my_route_table.id
}

# Create security group
resource "aws_security_group" "my_security_group" {
  name_prefix = "My Security Group"
  vpc_id      = aws_vpc.my_vpc.id

  ingress {
    from_port   = 80
    to_port     = 80
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }


}


resource "aws_security_group_rule" "lambda_sg_rule" {
  type        = "ingress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"] # Replace with the CIDR block of your client network or use ["0.0.0.0/0"] for open access
  security_group_id = aws_security_group.lambda_sg.id
}

resource "aws_security_group_rule" "lambda_sg_rule_egress" {
  type        = "egress"
  from_port   = 0
  to_port     = 65535
  protocol    = "tcp"
  cidr_blocks = ["0.0.0.0/0"]
  security_group_id = aws_security_group.lambda_sg.id
}

# Create Lambda function
resource "aws_lambda_function" "my_lambda_function" {
  filename         = "lambda.zip"
  function_name    = "lambda"
  role             = aws_iam_role.my_iam_role1.arn
  handler          = "lambda.lambda_handler"
  runtime          = "python3.9"
  timeout          = 63
  vpc_config {
    security_group_ids = [aws_security_group.my_security_group.id]
    subnet_ids         = [aws_subnet.my_subnet.id]
  }

  environment {
    variables = {
      subnet = "${aws_subnet.my_subnet.id}"
    }
  }
}

# Create IAM role for Lambda function
resource "aws_iam_role" "my_iam_role1" {
  name_prefix = "MyIAMRole"

  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Action = "sts:AssumeRole"
        
        Effect = "Allow"
        Principal = {
          Service = "lambda.amazonaws.com"
        }
      }
    ]
  })

  tags = {
    name_prefix = "My IAM Role"
  }
}

# Attach Lambda execution policy to IAM role
resource "aws_iam_role_policy_attachment" "my_iam_role_policy_attachment" {
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSLambdaBasicExecutionRole"
  role       = aws_iam_role.my_iam_role1.name
}

resource "aws_iam_role_policy_attachment" "ec2_policy" {
  policy_arn = "arn:aws:iam::aws:policy/AmazonEC2FullAccess"
  role       = aws_iam_role.my_iam_role1.name
}


resource "aws_iam_policy" "sns-policy" {
  name = "lambda-sns"

  policy = jsonencode({
    Version = "2012-10-17"
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "logs:CreateLogGroup",
        "logs:CreateLogStream",
        "logs:PutLogEvents"
      ],
      "Resource": "arn:aws:logs:*:*:*"
    },
    {
        "Effect": "Allow",
        "Action": [
            "sns:*"
        ],
        "Resource": "*"
    }
  ]
  })
}

resource "aws_iam_role_policy_attachment" "lambda-ec2-policy-attach" {
  policy_arn = aws_iam_policy.sns-policy.arn
  role = aws_iam_role.my_iam_role1.name
}



# Define the internet gateway
resource "aws_internet_gateway" "example" {
  vpc_id = aws_vpc.my_vpc.id
}


################ API GATEWAY ################

resource "aws_api_gateway_rest_api" "test-flavio-api-gateway" {
  name = "test-flavio-api-gateway"
  endpoint_configuration {
    types = ["REGIONAL"]
  }
}

resource "aws_api_gateway_resource" "person" {
  rest_api_id = aws_api_gateway_rest_api.test-flavio-api-gateway.id
  parent_id   = aws_api_gateway_rest_api.test-flavio-api-gateway.root_resource_id
  path_part   = "person"
}

// POST
resource "aws_api_gateway_method" "post" {
  rest_api_id       = aws_api_gateway_rest_api.test-flavio-api-gateway.id
  resource_id       = aws_api_gateway_resource.person.id
  http_method       = "POST"
  authorization     = "NONE"
  api_key_required  = false
}

resource "aws_api_gateway_integration" "integration" {
  rest_api_id             = aws_api_gateway_rest_api.test-flavio-api-gateway.id
  resource_id             = aws_api_gateway_resource.person.id
  http_method             = aws_api_gateway_method.post.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda_function.invoke_arn
}

// GET
resource "aws_api_gateway_method" "get" {
  rest_api_id       = aws_api_gateway_rest_api.test-flavio-api-gateway.id
  resource_id       = aws_api_gateway_resource.person.id
  http_method       = "GET"
  authorization     = "NONE"
  api_key_required  = false
}

resource "aws_api_gateway_integration" "integration-get" {
  rest_api_id             = aws_api_gateway_rest_api.test-flavio-api-gateway.id
  resource_id             = aws_api_gateway_resource.person.id
  http_method             = aws_api_gateway_method.get.http_method
  integration_http_method = "POST"
  type                    = "AWS_PROXY"
  uri                     = aws_lambda_function.my_lambda_function.invoke_arn
}

################ Deployment of API gateway ################

resource "aws_api_gateway_deployment" "deployment1" {
  rest_api_id = aws_api_gateway_rest_api.test-flavio-api-gateway.id

  triggers = {
    redeployment = sha1(jsonencode(aws_api_gateway_rest_api.test-flavio-api-gateway.body))
  }

  depends_on = [aws_api_gateway_integration.integration]
  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_api_gateway_stage" "example" {
  deployment_id = aws_api_gateway_deployment.deployment1.id
  rest_api_id   = aws_api_gateway_rest_api.test-flavio-api-gateway.id
  stage_name    =  "sample"
}

#output "complete_unvoke_url"   {value = "${aws_api_gateway_deployment.deployment1.invoke_url}


data "archive_file" "lambda_s3" {
  type = "zip"

  source_file = "lambda.py"
  output_path = "lambda.zip"
}

output "complete_unvoke_url" {
  description = "URL"
  value       = aws_api_gateway_deployment.deployment1.invoke_url
}