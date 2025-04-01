# Easy Azure Storage

A simple web application built with Flutter Web to access and manage files in Azure Storage containers.

## Features

- Login with Azure Storage credentials
- View list of files in a container
- Upload new files
- View file contents
- Download files
- Secure credential storage
- Responsive design

## Setup for Development

1. Install Flutter (https://flutter.dev/docs/get-started/install)
2. Clone this repository
3. Run `flutter pub get` to install dependencies
4. Run `flutter run -d chrome` to start the development server

## Deploy to GitHub Pages

1. Create a new repository on GitHub
2. Push your code to the repository
3. Run the following commands:
   ```bash
   flutter build web --base-href "/$REPO_NAME/"
   ```
4. Create a new branch called `gh-pages`
5. Copy the contents of the `build/web` directory to the root of the `gh-pages` branch
6. Push the `gh-pages` branch to GitHub
7. Go to your repository settings, enable GitHub Pages, and select the `gh-pages` branch as the source

## Usage

1. Get your Azure Storage account credentials:
   - Account Name
   - Account Key
   - Container Name
2. Visit the deployed website
3. Enter your credentials
4. Start managing your files!

## Security Note

This application stores your Azure Storage credentials securely in the browser using the Flutter Secure Storage package. However, as this is a client-side application, please ensure you're using it on a secure device and network.

## License

MIT License
