#!/bin/bash

echo "Creando tabla Logs..."
aws dynamodb create-table \
    --table-name Logs \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

echo "Creando tabla SecurityAlerts..."
aws dynamodb create-table \
    --table-name SecurityAlerts \
    --attribute-definitions AttributeName=id,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --billing-mode PAY_PER_REQUEST

echo "¡Tablas creadas exitosamente en DynamoDB!"