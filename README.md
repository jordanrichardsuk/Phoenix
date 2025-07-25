# Phoenix AI Chatbot

A serverless AI chatbot built for the University of East London (UEL) using AWS services and Claude AI models.

## 🚀 Features

- **Real-time Streaming Responses**: AI responses appear word-by-word with typing animation
- **Multi-language Support**: 80+ languages with complete UI translation
- **Voice Input/Output**: Speech recognition and text-to-speech capabilities
- **Dark/Light Themes**: Toggle between themes with persistent settings
- **Admin Console**: Model selection, RAG controls, and debug settings
- **User Authentication**: JWT-based auth with email verification
- **Chat History Management**: Session management with real-time updates
- **Responsive Design**: Mobile-first responsive interface
- **RAG Integration**: Knowledge base integration for enhanced responses

## 🏗️ Architecture

- **Frontend**: Pure HTML5/CSS3/JavaScript (no external frameworks)
- **Backend**: AWS Lambda functions with Python
- **Database**: Amazon DynamoDB with auto-scaling
- **AI Models**: Amazon Bedrock (Claude 3.5 Sonnet & Claude 3 Haiku)
- **Authentication**: Amazon Cognito with custom UI
- **Storage**: Amazon S3 for frontend hosting and document storage
- **CDN**: Amazon CloudFront for global distribution
- **Infrastructure**: AWS CloudFormation for IaC

## 📦 Repository Structure

```
phoenix/
├── index.html              # Complete frontend application
├── phoenix-claude.yaml     # CloudFormation infrastructure template
├── deploy.sh              # Automated deployment script
├── test-metrics.py        # CloudWatch metrics testing script
└── README.md             # This file
```

## 🔄 Git Workflow

### Branch Structure
- **`main`**: Stable, production-ready code
- **`develop`**: Integration branch for new features
- **`feature/*`**: Individual feature development branches

### Development Process
1. **Feature Development**: Create feature branches from `develop`
   ```bash
   git checkout develop
   git pull origin develop
   git checkout -b feature/your-feature-name
   ```

2. **Development**: Make changes and commit with detailed messages
   ```bash
   git add .
   git commit -m "feat: description of feature"
   ```

3. **Testing**: Deploy to dev environment and test thoroughly
   ```bash
   ./deploy.sh --dev --update
   ```

4. **Integration**: Merge feature to develop branch
   ```bash
   git checkout develop
   git merge feature/your-feature-name
   git push origin develop
   ```

5. **Release**: When develop is stable, merge to main
   ```bash
   git checkout main
   git merge develop
   git push origin main
   ```

## 🚀 Deployment

### Prerequisites
- AWS CLI configured with appropriate credentials
- Permissions for CloudFormation, S3, Lambda, DynamoDB, Cognito, Bedrock

### Deploy to Development
```bash
./deploy.sh --dev
```

### Deploy to Production
```bash
./deploy.sh --prod
```

## 🔧 Configuration

### Admin Console
Access via the ⚙️ button in the interface:
- **Model Selection**: Choose between Claude 3.5 Sonnet and Claude 3 Haiku
- **Adaptive Model**: Automatic model selection based on query complexity
- **RAG Toggle**: Enable/disable retrieval-augmented generation
- **Streaming**: Toggle real-time response streaming
- **Debug Mode**: Show system information and logs

### Environment Variables
Set via CloudFormation parameters:
- `Environment`: Deployment environment (dev/test/uat/prod)
- `DomainName`: Custom domain name (optional)
- `CertificateArn`: SSL certificate ARN for custom domain

## 📊 Monitoring

The application includes comprehensive CloudWatch monitoring:
- Business metrics (queries, costs, user satisfaction)
- Technical metrics (response times, error rates)
- Custom dashboard for real-time monitoring

Test metrics with:
```bash
python test-metrics.py
```

## 🐛 Recent Changes

See commit history for detailed changelog of all features and fixes.

## 📝 License

Proprietary - University of East London

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch from `develop`
3. Make your changes with proper testing
4. Submit a pull request to `develop` branch

---

**Live Application**: https://phoenix.dev.uel.ac.uk
**Repository**: https://github.com/jordanrichardsuk/Phoenix