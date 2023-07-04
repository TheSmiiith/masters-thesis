FROM ubuntu:23.10

# Environment variables
ARG AWS_DEFAULT_REGION=local
ENV AWS_DEFAULT_REGION=${AWS_DEFAULT_REGION}

ARG AWS_ACCESS_KEY_ID=local
ENV AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}

ARG AWS_SECRET_ACCESS_KEY=local
ENV AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}

# Install dependencies
RUN apt update
RUN apt install -y unzip
RUN apt install -y python3-pip
RUN apt install -y python3-boto3
RUN apt install -y python3-pillow

# Install AWS CLI
RUN apt install -y curl
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
RUN unzip awscliv2.zip
RUN ./aws/install --bin-dir /usr/local/bin --install-dir /usr/local/aws-cli --update
RUN rm -r -d aws
RUN rm -r -d awscliv2.zip

# Configure git
RUN apt install -y git
RUN git config --global credential.helper '!aws codecommit credential-helper $@'
RUN git config --global credential.UseHttpPath true

# Set working directory
WORKDIR /home/ubuntu

# Clone repository
RUN git clone https://git-codecommit.eu-central-1.amazonaws.com/v1/repos/MastersThesis

# Start the application
ENTRYPOINT python3 -u /home/ubuntu/MastersThesis/application/image-effecting-service/main.py