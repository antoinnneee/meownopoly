// Client WebSocket vers le serveur d'automation de l'app Meownopoly.
//
// Connexion lazy (à la première commande), reconnexion automatique si l'app a
// redémarré, et corrélation requête/réponse via un champ `id` incrémental.
// Une instance de client est maintenue par port (l'app peut tourner en 2
// instances avec des ports différents — cf. dual_test_p2p).

import { WebSocket } from "ws";

const DEFAULT_TIMEOUT_MS = 15000;

class AutomationClient {
  constructor(port) {
    this.port = port;
    this.ws = null;
    this.nextId = 1;
    this.pending = new Map(); // id -> { resolve, reject, timer }
    this.connecting = null; // Promise en cours de connexion
  }

  _url() {
    return `ws://127.0.0.1:${this.port}`;
  }

  async _ensureConnected() {
    if (this.ws && this.ws.readyState === WebSocket.OPEN) return;
    if (this.connecting) return this.connecting;

    this.connecting = new Promise((resolve, reject) => {
      const ws = new WebSocket(this._url());
      const onError = (err) => {
        this.connecting = null;
        reject(
          new Error(
            `Impossible de se connecter à l'app sur ${this._url()} : ${err.message}. ` +
              `Lance l'app avec --automation-port ${this.port} (ou MEOW_AUTOMATION_PORT=${this.port}).`
          )
        );
      };
      ws.once("error", onError);
      ws.once("open", () => {
        ws.removeListener("error", onError);
        this.ws = ws;
        this.connecting = null;

        ws.on("message", (data) => this._onMessage(data));
        ws.on("close", () => {
          this.ws = null;
          // Rejeter toutes les requêtes en attente : l'app a fermé la connexion.
          for (const [, p] of this.pending) {
            clearTimeout(p.timer);
            p.reject(new Error("Connexion fermée par l'app (a-t-elle quitté ?)"));
          }
          this.pending.clear();
        });
        ws.on("error", () => {
          // Géré par close/onMessage ; on évite un crash du process MCP.
        });
        resolve();
      });
    });
    return this.connecting;
  }

  _onMessage(data) {
    let msg;
    try {
      msg = JSON.parse(data.toString());
    } catch {
      return; // message non-JSON ignoré
    }
    const id = msg.id;
    const p = this.pending.get(id);
    if (!p) return;
    this.pending.delete(id);
    clearTimeout(p.timer);
    if (msg.ok) {
      p.resolve(msg.result);
    } else {
      p.reject(new Error(typeof msg.error === "string" ? msg.error : JSON.stringify(msg.error)));
    }
  }

  // Envoie une commande et attend la réponse corrélée.
  async send(cmd, params = {}, timeoutMs = DEFAULT_TIMEOUT_MS) {
    await this._ensureConnected();
    const id = this.nextId++;
    const payload = JSON.stringify({ id, cmd, params });

    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        this.pending.delete(id);
        reject(new Error(`Timeout (${timeoutMs} ms) en attente de la réponse à '${cmd}'`));
      }, timeoutMs);
      this.pending.set(id, { resolve, reject, timer });
      try {
        this.ws.send(payload);
      } catch (err) {
        this.pending.delete(id);
        clearTimeout(timer);
        reject(err);
      }
    });
  }
}

// Pool de clients indexé par port.
const clients = new Map();

export function getClient(port) {
  const p = Number(port);
  if (!clients.has(p)) clients.set(p, new AutomationClient(p));
  return clients.get(p);
}
