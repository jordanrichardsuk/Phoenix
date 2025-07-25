#!/usr/bin/env python3
"""
Test script to verify Phoenix chatbot metrics are being sent to CloudWatch.
This script will make test requests to your Phoenix chatbot and check if metrics appear in CloudWatch.
"""

import requests
import json
import time
import boto3
from datetime import datetime, timedelta

# Configuration - Update these values for your deployment
API_ENDPOINT = "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/YOUR_ENVIRONMENT"
TEST_USER_TOKEN = "YOUR_JWT_TOKEN_HERE"  # Get this from your app after login

def test_chat_request():
    """Test a chat request to generate metrics"""
    print("🚀 Testing chat request...")
    
    headers = {
        'Authorization': f'Bearer {TEST_USER_TOKEN}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'message': 'Hello Phoenix! This is a test message to generate metrics.',
        'sessionId': f'test-session-{int(time.time())}',
        'messageId': f'test-msg-{int(time.time())}',
        'history': [],
        'language': 'en',
        'model': 'sonnet',
        'ragEnabled': True,
        'streamingEnabled': False
    }
    
    try:
        response = requests.post(f'{API_ENDPOINT}/chat', 
                               headers=headers, 
                               json=payload, 
                               timeout=30)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Chat request successful!")
            print(f"   Response length: {len(data.get('response', ''))}")
            if 'metrics' in data:
                print(f"   Tokens used: {data['metrics'].get('tokensUsed', 0)}")
                print(f"   Cost: ${data['metrics'].get('cost', 0):.6f}")
                print(f"   Response time: {data['metrics'].get('responseTime', 0):.2f}s")
            print(f"   Model used: {data.get('modelUsed', 'unknown')}")
            print(f"   RAG enabled: {data.get('ragEnabled', False)}")
            return True
        else:
            print(f"❌ Chat request failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error making chat request: {e}")
        return False

def test_feedback_request():
    """Test a feedback request to generate metrics"""
    print("\n👍 Testing feedback request...")
    
    headers = {
        'Authorization': f'Bearer {TEST_USER_TOKEN}',
        'Content-Type': 'application/json'
    }
    
    payload = {
        'feedbackType': 'good',
        'feedbackText': 'This is a test positive feedback for metrics!',
        'messageId': f'test-msg-{int(time.time())}',
        'sessionId': f'test-session-{int(time.time())}',
        'messageContent': 'Test message content',
        'userEmail': 'test@example.com',
        'userName': 'Test User'
    }
    
    try:
        response = requests.post(f'{API_ENDPOINT}/feedback', 
                               headers=headers, 
                               json=payload, 
                               timeout=10)
        
        if response.status_code == 200:
            data = response.json()
            print("✅ Feedback request successful!")
            print(f"   Feedback ID: {data.get('feedbackId', 'unknown')}")
            return True
        else:
            print(f"❌ Feedback request failed: {response.status_code}")
            print(f"   Response: {response.text}")
            return False
            
    except Exception as e:
        print(f"❌ Error making feedback request: {e}")
        return False

def check_cloudwatch_metrics():
    """Check if metrics are appearing in CloudWatch"""
    print("\n📊 Checking CloudWatch metrics...")
    
    try:
        cloudwatch = boto3.client('cloudwatch')
        
        # Check for metrics in the Phoenix/Business namespace
        end_time = datetime.utcnow()
        start_time = end_time - timedelta(minutes=10)
        
        # List of metrics to check
        metrics_to_check = [
            'TotalQueries',
            'TokensUsed', 
            'BedrockCost',
            'QueriesPerHour',
            'ActiveUsers',
            'ModelUsage',
            'UserSatisfaction'
        ]
        
        metrics_found = []
        
        for metric_name in metrics_to_check:
            try:
                response = cloudwatch.get_metric_statistics(
                    Namespace='Phoenix/Business',
                    MetricName=metric_name,
                    StartTime=start_time,
                    EndTime=end_time,
                    Period=300,
                    Statistics=['Sum', 'Average', 'Maximum']
                )
                
                if response['Datapoints']:
                    metrics_found.append(metric_name)
                    latest_value = max(response['Datapoints'], key=lambda x: x['Timestamp'])
                    print(f"   ✅ {metric_name}: {latest_value.get('Sum', latest_value.get('Average', latest_value.get('Maximum', 0)))}")
                else:
                    print(f"   ⏳ {metric_name}: No data yet (may take up to 5 minutes)")
                    
            except Exception as e:
                print(f"   ❌ {metric_name}: Error checking - {e}")
        
        if metrics_found:
            print(f"\n✅ Found {len(metrics_found)} metrics with data!")
            return True
        else:
            print(f"\n⏳ No metrics found yet - they may take 2-5 minutes to appear in CloudWatch")
            return False
            
    except Exception as e:
        print(f"❌ Error checking CloudWatch metrics: {e}")
        return False

def get_dashboard_url():
    """Get the dashboard URL from CloudFormation stack outputs"""
    print("\n🎯 Getting dashboard URL...")
    
    try:
        cf = boto3.client('cloudformation')
        
        # You'll need to update this with your actual stack name
        stack_name = "phoenix-dev-stack"  # Update this!
        
        response = cf.describe_stacks(StackName=stack_name)
        
        for output in response['Stacks'][0]['Outputs']:
            if output['OutputKey'] == 'BusinessDashboardURL':
                print(f"📊 Dashboard URL: {output['OutputValue']}")
                return output['OutputValue']
        
        print("❌ Dashboard URL not found in stack outputs")
        return None
        
    except Exception as e:
        print(f"❌ Error getting dashboard URL: {e}")
        return None

def main():
    """Run all tests"""
    print("🧪 Phoenix Metrics Test Suite")
    print("=" * 50)
    
    # Check configuration
    if API_ENDPOINT == "https://YOUR_API_ID.execute-api.YOUR_REGION.amazonaws.com/YOUR_ENVIRONMENT":
        print("❌ Please update API_ENDPOINT in this script with your actual API Gateway URL")
        return
        
    if TEST_USER_TOKEN == "YOUR_JWT_TOKEN_HERE":
        print("❌ Please update TEST_USER_TOKEN in this script with a valid JWT token")
        print("   You can get this by logging into your Phoenix app and checking the network requests")
        return
    
    # Run tests
    success_count = 0
    
    if test_chat_request():
        success_count += 1
    
    if test_feedback_request():
        success_count += 1
    
    print(f"\n⏱️  Waiting 30 seconds for metrics to propagate...")
    time.sleep(30)
    
    if check_cloudwatch_metrics():
        success_count += 1
    
    dashboard_url = get_dashboard_url()
    
    print("\n" + "=" * 50)
    print(f"📊 Test Results: {success_count}/3 tests completed successfully")
    
    if success_count >= 2:
        print("🎉 Metrics system is working! Check your CloudWatch dashboard.")
        if dashboard_url:
            print(f"🎯 View your dashboard: {dashboard_url}")
    else:
        print("⚠️  Some issues detected. Check the errors above.")
    
    print("\n💡 Tips:")
    print("   - Metrics may take 2-5 minutes to appear in CloudWatch")
    print("   - Make sure your Lambda functions have CloudWatch permissions")
    print("   - Check CloudWatch Logs for any errors in your Lambda functions")

if __name__ == "__main__":
    main()