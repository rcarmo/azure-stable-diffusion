from subprocess import check_output
from json import loads
from textual.app import App, ComposeResult
from textual.containers import Container
from textual.widgets import Header, Footer, Button, Static

status = None

class StatusLabel(Static):
    pass

class VMStatus(Static):
    def compose(self) -> ComposeResult:
        global status
        if "running" in status["powerState"]:
            yield Button("Stop", id="stop", variant="error")
        else:
            yield Button("Start", id="start", variant="success")
        yield StatusLabel(status["powerState"])

class IPStatus(Static):
    def compose(self) -> ComposeResult:
        global status
        if "publicIps" in status:
            ip = "Public IP: " + status["publicIps"]
            yield Button("Remove", id="remove", variant="error")
        else:
            ip = "No Public IP"
            yield Button("Allocate", id="allocate", variant="success")
        yield StatusLabel(ip)

class Main(App):

    CSS_PATH = "tui.css"
    BINDINGS = [("d", "toggle_dark", "Toggle dark mode")]

    def compose(self) -> ComposeResult:
        global status
        """Create child widgets for the app."""
        status = loads(check_output("make get-vm-details", shell=True))[0]
        yield Header()
        yield Footer()
        yield Container(VMStatus(), IPStatus())

    def action_toggle_dark(self) -> None:
        """An action to toggle dark mode."""
        self.dark = not self.dark

if __name__ == "__main__":
    app = Main()
    app.run()