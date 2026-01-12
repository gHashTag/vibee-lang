import * as path from 'path';
import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient | undefined;

export function activate(context: vscode.ExtensionContext) {
    const config = vscode.workspace.getConfiguration('vib');
    const lspEnabled = config.get<boolean>('lsp.enabled', true);

    if (!lspEnabled) {
        console.log('VIB LSP is disabled');
        return;
    }

    // Get the path to the LSP server
    let serverPath = config.get<string>('lsp.path', '');

    if (!serverPath) {
        // Try to find the run_lsp.sh in the workspace
        const workspaceFolders = vscode.workspace.workspaceFolders;
        if (workspaceFolders) {
            for (const folder of workspaceFolders) {
                const possiblePath = path.join(folder.uri.fsPath, 'gleam', 'run_lsp.sh');
                if (require('fs').existsSync(possiblePath)) {
                    serverPath = possiblePath;
                    break;
                }
            }
        }
    }

    if (!serverPath) {
        vscode.window.showWarningMessage(
            'VIB LSP server path not configured. Set vib.lsp.path in settings.'
        );
        return;
    }

    // Server options - run the shell script
    const serverOptions: ServerOptions = {
        run: {
            command: serverPath,
            transport: TransportKind.stdio
        },
        debug: {
            command: serverPath,
            transport: TransportKind.stdio
        }
    };

    // Client options
    const clientOptions: LanguageClientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'vib' }
        ],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{vib,vibe}')
        },
        outputChannelName: 'VIB Language Server'
    };

    // Create the language client
    client = new LanguageClient(
        'vib',
        'VIB Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client
    client.start().then(() => {
        console.log('VIB Language Server started');
    }).catch((error) => {
        console.error('Failed to start VIB Language Server:', error);
        vscode.window.showErrorMessage(`Failed to start VIB LSP: ${error.message}`);
    });

    context.subscriptions.push({
        dispose: () => {
            if (client) {
                client.stop();
            }
        }
    });
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
