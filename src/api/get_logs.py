import json
import boto3
from boto3.dynamodb.conditions import Key
from decimal import Decimal

dynamodb = boto3.resource('dynamodb')
table = dynamodb.Table('Logs')

class DecimalEncoder(json.JSONEncoder):
    def default(self, obj):
        if isinstance(obj, Decimal):
            return float(obj)
        return super(DecimalEncoder, self).default(obj)

def lambda_handler(event, context):
    try:
        # Extraemos el parámetro 'top' de la URL (ej. /logs?top=5). Si no viene, por defecto es 10.
        params = event.get('queryStringParameters') or {}
        top_n = int(params.get('top', 10))

        # Hacemos Query sobre el Índice Secundario Global
        response = table.query(
            IndexName='RecentLogsIndex',
            KeyConditionExpression=Key('log_type').eq('syslog'),
            ScanIndexForward=False, # Esto invierte el orden (descendente)
            Limit=top_n
        )
        
        return {
            "statusCode": 200,
            "body": json.dumps(response.get('Items', []), cls=DecimalEncoder)
        }
    except Exception as e:
        return {"statusCode": 500, "body": str(e)}