# 🌐 Módulo Multiplayer Plug-and-Play para Godot 4

Módulo autossuficiente e pronto para produção de **Lobby, Chat e Gerenciamento de Rede** para jogos multiplayer na Godot 4 (4.0+ / 4.6+).

---

## 📂 Arquivos Incluídos

Todos os arquivos necessários estão contidos nesta pasta:

| Arquivo | Função |
| :--- | :--- |
| **`NetworkManager.gd`** | Gerenciador global de rede ENet, ping, reconexão, kick, ban por IP e sanitização de nicks. |
| **`SceneManager.gd`** | Script do gerenciador de fluxo de cenas com tela de transição (*fade*). |
| **`scene_manager.tscn`** | Cena do SceneManager com export properties para definir o Menu e o Jogo pelo Inspetor. |
| **`chat_ui.gd`** | Lógica de chat com auto-fade tween, foco via Enter/ESC, limite de flood e segurança anti-BBCode. |
| **`chat_ui.tscn`** | Interface visual do chat em CanvasLayer (estilo translúcido arredondado). |
| **`main_menu.tscn`** | Interface de Menu (Host, Join, IP, Porta, Max Players) e Sala de Espera (Lobby). |
| **`main_menu.gd`** | Script de validação de inputs e persistência automática em `user://network_settings.cfg`. |
| **`lobby.gd`** | Lógica do Lobby: slots reativos sem flicker, ready check, ping em tempo real e moderação do host. |

---

## 🚀 Como Instalar em um Novo Projeto (Copiar e Colar)

### 1. Copie a pasta
Copie a pasta `multiplayer/` inteira diretamente para a raiz `res://` do seu novo projeto.

```text
res://
├── multiplayer/
│   ├── NetworkManager.gd
│   ├── SceneManager.gd
│   ├── scene_manager.tscn
│   ├── chat_ui.gd
│   ├── chat_ui.tscn
│   ├── main_menu.gd
│   ├── main_menu.tscn
│   ├── lobby.gd
│   └── README.md
└── (seus arquivos do jogo...)
```

---

### 2. Cadastre os 3 Autoloads (Singletons)

No seu novo projeto, vá em **Project > Project Settings > Globals > Autoload** e adicione exatamente estes 3 nós:

| Node Name | Path | Tipo |
| :--- | :--- | :--- |
| **`NetworkManager`** | `res://multiplayer/NetworkManager.gd` | *Script* |
| **`ChatUi`** | `res://multiplayer/chat_ui.tscn` | *Cena (.tscn)* ⚠️ |
| **`SceneManager`** | `res://multiplayer/scene_manager.tscn` | *Cena (.tscn)* ⚠️ |

> ⚠️ **Atenção:** Certifique-se de selecionar o arquivo **`.tscn`** para `ChatUi` e `SceneManager` (e não o `.gd`), pois eles contêm a estrutura visual e os parâmetros exportados.

---

### 3. Aponte a Cena do seu Jogo

1. No FileSystem da Godot, dê duplo clique em `res://multiplayer/scene_manager.tscn`.
2. Selecione o nó raiz **`SceneManager`**.
3. No **Inspetor** (à direita), defina:
   - **`Main Menu Scene`**: `res://multiplayer/main_menu.tscn`
   - **`Game Scene`**: Selecione o arquivo da cena do seu jogo/partida (ex: `res://arenas/game_world.tscn`).
4. Salve a cena (`Ctrl + S`).

---

### 4. Defina o Menu como Cena Principal (Opcional)

Vá em **Project > Project Settings > Application > Run > Main Scene** e selecione `res://multiplayer/main_menu.tscn`.

---

## 💡 Como Interagir com o Módulo no seu Jogo

### 1. Acessar dados dos jogadores conectados
```gdscript
# Dicionário contendo todos os jogadores: { peer_id: {"nickname": "...", "ready": bool, "ping": int} }
var players = NetworkManager.players_data

# Identificador do jogador local
var meu_id = multiplayer.get_unique_id()

# Saber se é o host/servidor
if multiplayer.is_server():
    print("Sou o Host!")
```

### 2. Enviar mensagens de sistema no Chat
```gdscript
# Mensagem informativa neutra (cinza-azulada em itálico):
ChatUi.system_message("O jogador encontrou uma chave secreta!", false)

# Mensagem de alerta/atenção (coral/vermelho em itálico):
ChatUi.system_message("A tempestade começou!", true)
```

### 3. Mudar de cena com transição suave (Fade)
```gdscript
# Somente o servidor deve comandar a troca de cena sincronizada:
if multiplayer.is_server():
    SceneManager.change_scene.rpc("res://mapas/fase_2.tscn")
```

### 4. Sair da partida / Retornar ao Menu
```gdscript
# Desconecta o peer, limpa a sessão e retorna suavemente para o menu principal:
NetworkManager.leave_lobby()
```

---

## 🔒 Recursos de Produção Inclusos

- **Compressão ENet (`COMPRESS_RANGE_CODER`)**: Otimização automática de tráfego de rede.
- **Fast Timeout (3s a 7s)**: Limpeza ágil de clientes desconectados sem travamento.
- **Deduplicação de Apelidos**: Nomes vazios viram `Player <ID>` e repetidos ganham sufixo `(1)`, `(2)`.
- **Moderação Completa do Host**: Expulsão (*Kick*) e Banimento definitivo por IP (*Ban*) com interface de desbanimento (*Banlist*).
- **Proteção Anti-Flood & Anti-BBCode**: Taxa de envio controlada no cliente e servidor, prevenindo injeções visuais e travamentos.
- **Lock de Sala em Jogo**: Novas conexões são automaticamente recusadas enquanto a partida estiver rolando.
- **Persistência de Conexão**: Lembra IP, Porta e Nickname digitados pelo jogador em `user://network_settings.cfg`.
