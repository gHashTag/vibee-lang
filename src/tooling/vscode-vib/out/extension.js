"use strict";
var __createBinding = (this && this.__createBinding) || (Object.create ? (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    var desc = Object.getOwnPropertyDescriptor(m, k);
    if (!desc || ("get" in desc ? !m.__esModule : desc.writable || desc.configurable)) {
      desc = { enumerable: true, get: function() { return m[k]; } };
    }
    Object.defineProperty(o, k2, desc);
}) : (function(o, m, k, k2) {
    if (k2 === undefined) k2 = k;
    o[k2] = m[k];
}));
var __setModuleDefault = (this && this.__setModuleDefault) || (Object.create ? (function(o, v) {
    Object.defineProperty(o, "default", { enumerable: true, value: v });
}) : function(o, v) {
    o["default"] = v;
});
var __importStar = (this && this.__importStar) || (function () {
    var ownKeys = function(o) {
        ownKeys = Object.getOwnPropertyNames || function (o) {
            var ar = [];
            for (var k in o) if (Object.prototype.hasOwnProperty.call(o, k)) ar[ar.length] = k;
            return ar;
        };
        return ownKeys(o);
    };
    return function (mod) {
        if (mod && mod.__esModule) return mod;
        var result = {};
        if (mod != null) for (var k = ownKeys(mod), i = 0; i < k.length; i++) if (k[i] !== "default") __createBinding(result, mod, k[i]);
        __setModuleDefault(result, mod);
        return result;
    };
})();
Object.defineProperty(exports, "__esModule", { value: true });
exports.activate = activate;
exports.deactivate = deactivate;
const path = __importStar(require("path"));
const vscode = __importStar(require("vscode"));
const node_1 = require("vscode-languageclient/node");
let client;
function activate(context) {
    const config = vscode.workspace.getConfiguration('vib');
    const lspEnabled = config.get('lsp.enabled', true);
    if (!lspEnabled) {
        console.log('VIB LSP is disabled');
        return;
    }
    // Get the path to the LSP server
    let serverPath = config.get('lsp.path', '');
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
        vscode.window.showWarningMessage('VIB LSP server path not configured. Set vib.lsp.path in settings.');
        return;
    }
    // Server options - run the shell script
    const serverOptions = {
        run: {
            command: serverPath,
            transport: node_1.TransportKind.stdio
        },
        debug: {
            command: serverPath,
            transport: node_1.TransportKind.stdio
        }
    };
    // Client options
    const clientOptions = {
        documentSelector: [
            { scheme: 'file', language: 'vib' }
        ],
        synchronize: {
            fileEvents: vscode.workspace.createFileSystemWatcher('**/*.{vib,vibe}')
        },
        outputChannelName: 'VIB Language Server'
    };
    // Create the language client
    client = new node_1.LanguageClient('vib', 'VIB Language Server', serverOptions, clientOptions);
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
function deactivate() {
    if (!client) {
        return undefined;
    }
    return client.stop();
}
//# sourceMappingURL=extension.js.map