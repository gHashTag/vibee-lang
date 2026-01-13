import * as path from 'path';
import * as vscode from 'vscode';
import {
    LanguageClient,
    LanguageClientOptions,
    ServerOptions,
    TransportKind
} from 'vscode-languageclient/node';

let client: LanguageClient;

export function activate(context: vscode.ExtensionContext) {
    // Get LSP server path from configuration
    const config = vscode.workspace.getConfiguration('vibee');
    const lspPath = config.get<string>('lspPath', 'vibeec-lsp');

    // Server options
    const serverOptions: ServerOptions = {
        run: {
            command: lspPath,
            transport: TransportKind.stdio
        },
        debug: {
            command: lspPath,
            transport: TransportKind.stdio
        }
    };

    // Client options
    const clientOptions: LanguageClientOptions = {
        documentSelector: [{ scheme: 'file', language: 'vibee' }],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.vibee')
        }
    };

    // Create and start the client
    client = new LanguageClient(
        'vibee',
        'VIBEE Language Server',
        serverOptions,
        clientOptions
    );

    // Start the client
    client.start();

    // Register commands
    context.subscriptions.push(
        vscode.commands.registerCommand('vibee.restartServer', async () => {
            await client.stop();
            await client.start();
            vscode.window.showInformationMessage('VIBEE Language Server restarted');
        })
    );

    context.subscriptions.push(
        vscode.commands.registerCommand('vibee.showVersion', () => {
            vscode.window.showInformationMessage('VIBEE Language Extension v0.1.0');
        })
    );

    console.log('VIBEE Language Extension activated');
}

export function deactivate(): Thenable<void> | undefined {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
