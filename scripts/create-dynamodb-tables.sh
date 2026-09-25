#!/bin/bash

echo "Creando tabla Logs (con GSI para ordenar por tiempo de llegada)..."
aws dynamodb create-table \
    --table-name Logs \
    --attribute-definitions \
        AttributeName=id,AttributeType=S \
        AttributeName=log_type,AttributeType=S \
        AttributeName=batch_timestamp,AttributeType=S \
    --key-schema AttributeName=id,KeyType=HASH \
    --global-secondary-indexes "IndexName=RecentLogsIndex,KeySchema=[{AttributeName=log_type,KeyType=HASH},{AttributeName=batch_timestamp,KeyType=RANGE}],Projection={ProjectionType=ALL}" \
    --billing-mode PAY_PER_REQUEST

echo "Creando tabla SecurityAlerts (optimizada para hacer Query)..."
aws dynamodb create-table \
    --table-name SecurityAlerts \
    --attribute-definitions \
        AttributeName=alert_status,AttributeType=S \
        AttributeName=batch_timestamp,AttributeType=S \
    --key-schema AttributeName=alert_status,KeyType=HASH AttributeName=batch_timestamp,KeyType=RANGE \
    --billing-mode PAY_PER_REQUEST

echo "¡Tablas creadas exitosamente en DynamoDB!"