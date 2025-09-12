import json
import logging
import os
import requests
from datetime import datetime
from google.cloud import functions_v1
from flask import Request, jsonify

# Configuration
WORKER_URL = os.environ.get('WORKER_URL', 'https://gaia-x.workers.dev')
AZURE_FUNCTION_URL = os.environ.get('AZURE_FUNCTION_URL', 'https://agentazure.azurewebsites.net/api')

def gaia_x_orchestrate(request: Request):
    """
    Google Cloud Function for Gaia-X orchestration
    HTTP Cloud Function to handle orchestration requests
    """
    # Set CORS headers
    headers = {
        'Access-Control-Allow-Origin': '*',
        'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
        'Access-Control-Allow-Headers': 'Content-Type, Authorization'
    }
    
    # Handle CORS preflight requests
    if request.method == 'OPTIONS':
        return ('', 204, headers)
    
    try:
        # Parse request data
        if request.method == 'POST':
            request_json = request.get_json(silent=True)
            if not request_json:
                request_json = {}
        else:
            request_json = {}
        
        # Extract parameters
        operation = request_json.get('operation', request.args.get('operation', 'status'))
        platform = request_json.get('platform', request.args.get('platform', 'gcloud'))
        parameters = request_json.get('parameters', {})
        
        logging.info(f'GCloud function processing: {operation} for {platform}')
        
        # Handle different operations
        result = {}
        
        if operation == 'status':
            result = handle_status_check()
        elif operation == 'deploy':
            result = handle_deployment(platform, parameters)
        elif operation == 'voice-command':
            result = handle_voice_command(request_json)
        elif operation == 'orchestrate':
            result = handle_orchestration(request_json)
        else:
            result = {
                'error': f'Unknown operation: {operation}',
                'available_operations': ['status', 'deploy', 'voice-command', 'orchestrate']
            }
            return (json.dumps(result), 400, {**headers, 'Content-Type': 'application/json'})
        
        return (json.dumps(result, indent=2), 200, {**headers, 'Content-Type': 'application/json'})
    
    except Exception as e:
        logging.error(f'Error in GCloud function: {str(e)}')
        error_result = {
            'error': 'Internal server error',
            'details': str(e),
            'timestamp': datetime.utcnow().isoformat()
        }
        return (json.dumps(error_result), 500, {**headers, 'Content-Type': 'application/json'})

def handle_status_check():
    """Check status of Google Cloud and other platforms"""
    try:
        status_data = {
            'gcloud': {
                'status': 'healthy',
                'function': 'running',
                'timestamp': datetime.utcnow().isoformat(),
                'region': os.environ.get('FUNCTION_REGION', 'unknown'),
                'project': os.environ.get('GCP_PROJECT', 'unknown')
            }
        }
        
        # Check other platforms
        try:
            # Check Cloudflare Worker
            worker_response = requests.get(f'{WORKER_URL}/health', timeout=10)
            if worker_response.status_code == 200:
                status_data['cloudflare'] = {
                    'status': 'healthy',
                    'worker': 'online'
                }
            else:
                status_data['cloudflare'] = {
                    'status': 'unhealthy',
                    'worker': 'offline'
                }
        except Exception as e:
            status_data['cloudflare'] = {
                'status': 'error',
                'error': str(e)
            }
        
        try:
            # Check Azure Function
            azure_response = requests.get(f'{AZURE_FUNCTION_URL}/orchestrate?operation=status', timeout=10)
            if azure_response.status_code == 200:
                status_data['azure'] = {
                    'status': 'healthy',
                    'function': 'online'
                }
            else:
                status_data['azure'] = {
                    'status': 'unhealthy',
                    'function': 'offline'
                }
        except Exception as e:
            status_data['azure'] = {
                'status': 'error',
                'error': str(e)
            }
        
        return status_data
    
    except Exception as e:
        logging.error(f'Error in status check: {str(e)}')
        return {'error': str(e)}

def handle_deployment(platform: str, parameters: dict):
    """Handle deployment operations"""
    try:
        deployment_result = {
            'platform': platform,
            'operation': 'deploy',
            'status': 'initiated',
            'timestamp': datetime.utcnow().isoformat(),
            'parameters': parameters
        }
        
        if platform == 'gcloud' or platform == 'google':
            # Google Cloud-specific deployment logic
            deployment_result.update({
                'status': 'completed',
                'message': 'Google Cloud Function deployment successful',
                'function_name': os.environ.get('K_SERVICE', 'gaia-x-orchestrate'),
                'project': os.environ.get('GCP_PROJECT', 'unknown')
            })
        
        elif platform == 'cloudflare':
            # Forward to Cloudflare Worker
            try:
                worker_response = requests.post(
                    f'{WORKER_URL}/orchestrate',
                    json={
                        'operation': 'deploy',
                        'platform': 'cloudflare',
                        'parameters': parameters
                    },
                    timeout=30
                )
                if worker_response.status_code == 200:
                    deployment_result.update({
                        'status': 'completed',
                        'message': 'Cloudflare deployment triggered from Google Cloud'
                    })
                else:
                    deployment_result.update({
                        'status': 'failed',
                        'error': 'Failed to trigger Cloudflare deployment'
                    })
            except Exception as e:
                deployment_result.update({
                    'status': 'failed',
                    'error': f'Cloudflare deployment error: {str(e)}'
                })
        
        elif platform == 'azure':
            # Forward to Azure Function
            try:
                azure_response = requests.post(
                    f'{AZURE_FUNCTION_URL}/orchestrate',
                    json={
                        'operation': 'deploy',
                        'platform': 'azure',
                        'parameters': parameters
                    },
                    timeout=30
                )
                if azure_response.status_code == 200:
                    deployment_result.update({
                        'status': 'completed',
                        'message': 'Azure deployment triggered from Google Cloud'
                    })
                else:
                    deployment_result.update({
                        'status': 'failed',
                        'error': 'Failed to trigger Azure deployment'
                    })
            except Exception as e:
                deployment_result.update({
                    'status': 'failed',
                    'error': f'Azure deployment error: {str(e)}'
                })
        
        else:
            deployment_result.update({
                'status': 'failed',
                'error': f'Unknown platform: {platform}'
            })
        
        return deployment_result
    
    except Exception as e:
        logging.error(f'Error in deployment handler: {str(e)}')
        return {'error': str(e)}

def handle_voice_command(request_data: dict):
    """Handle voice command processing"""
    try:
        command = request_data.get('command')
        context = request_data.get('context', {})
        
        if not command:
            return {'error': 'Missing command field'}
        
        # Process Google Cloud specific commands
        if 'gcloud' in command.lower() or 'google' in command.lower():
            result = {
                'command': command,
                'platform': 'gcloud',
                'status': 'processed',
                'response': f'Google Cloud command "{command}" processed successfully',
                'timestamp': datetime.utcnow().isoformat()
            }
        else:
            # Forward to Worker for general processing
            try:
                worker_response = requests.post(
                    f'{WORKER_URL}/voice-command',
                    json={'command': command, 'context': context},
                    timeout=30
                )
                if worker_response.status_code == 200:
                    result = worker_response.json()
                    result['forwarded_from'] = 'gcloud'
                else:
                    result = {
                        'error': 'Failed to process voice command',
                        'status_code': worker_response.status_code
                    }
            except Exception as e:
                result = {
                    'error': f'Voice command processing error: {str(e)}',
                    'command': command
                }
        
        return result
    
    except Exception as e:
        logging.error(f'Error in voice command handler: {str(e)}')
        return {'error': str(e)}

def handle_orchestration(request_data: dict):
    """Handle multi-platform orchestration"""
    try:
        platforms = request_data.get('platforms', ['gcloud'])
        operation = request_data.get('operation', 'status')
        parameters = request_data.get('parameters', {})
        
        orchestration_result = {
            'orchestration_id': f'gcloud_{int(datetime.utcnow().timestamp())}',
            'operation': operation,
            'platforms': platforms,
            'status': 'initiated',
            'timestamp': datetime.utcnow().isoformat(),
            'results': {}
        }
        
        # Process each platform
        for platform in platforms:
            if platform == 'gcloud':
                orchestration_result['results'][platform] = {
                    'status': 'completed',
                    'message': 'Google Cloud orchestration successful'
                }
            else:
                # Forward to appropriate platform
                try:
                    if platform == 'cloudflare':
                        url = f'{WORKER_URL}/orchestrate'
                    elif platform == 'azure':
                        url = f'{AZURE_FUNCTION_URL}/orchestrate'
                    else:
                        orchestration_result['results'][platform] = {
                            'status': 'failed',
                            'error': f'Unknown platform: {platform}'
                        }
                        continue
                    
                    response = requests.post(
                        url,
                        json={
                            'operation': operation,
                            'platform': platform,
                            'parameters': parameters
                        },
                        timeout=30
                    )
                    
                    if response.status_code == 200:
                        orchestration_result['results'][platform] = {
                            'status': 'completed',
                            'response': response.json()
                        }
                    else:
                        orchestration_result['results'][platform] = {
                            'status': 'failed',
                            'error': f'HTTP {response.status_code}'
                        }
                
                except Exception as e:
                    orchestration_result['results'][platform] = {
                        'status': 'failed',
                        'error': str(e)
                    }
        
        # Update overall status
        failed_platforms = [p for p, r in orchestration_result['results'].items() if r['status'] == 'failed']
        if not failed_platforms:
            orchestration_result['status'] = 'completed'
        elif len(failed_platforms) == len(platforms):
            orchestration_result['status'] = 'failed'
        else:
            orchestration_result['status'] = 'partial'
        
        return orchestration_result
    
    except Exception as e:
        logging.error(f'Error in orchestration handler: {str(e)}')
        return {'error': str(e)}