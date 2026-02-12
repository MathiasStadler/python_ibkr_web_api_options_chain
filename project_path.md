# project_path
<!-- KtF-->
## ibkr start
<!-- KtF-->
```bash <!-- markdownlint-disable-line code-block-style -->
cd ~/clientportal.gw$ && ./bin/run.sh ./root/conf.yaml
``
<!-- KtF-->
## python version
<!-- KtF-->
```bash <!-- markdownlint-disable-line code-block-style -->
python3 --version
Python 3.13.5
```
<!-- ktf -->
<!-- ktf -->
## python install pip
<!-- KtF-->
```bash <!-- markdownlint-disable-line code-block-style -->
sudo apt install python3-pip
```
<!-- ktf -->
## python install requests
<!--ktf-->
```bash <!-- markdownlint-disable-line code-block-style -->
sudo apt-get -y install python3-requests
```
<!-- KtF-->
## python install env
<!-- KtF-->
```bash <!-- markdownlint-disable-line code-block-style -->
#as root
sudo apt install python3.13-venv
```
<!-- ktf -->
## create venv
<!-- ktf -->
install venv — Creation of virtual environments [![alt text][1]](https://docs.python.org/3/library/venv.html))
<!-- ktf -->
```bash
python3 -m venv .venv
```
<!-- ktf -->
## enter into .venv
<!-- ktf -->
```bash
source .venv/bin/activate
```
<!-- ktf -->
## list installed packages
<!-- ktf -->
```bash
pip list
```
<!-- ktf -->
## install packages
<!-- ktf -->
```bash
pip install requests
pip install urllib3
```
<!-- ktf -->
## exit/leave .venv
<!-- ktf -->
```bash
deactivate
```
<!-- ktf -->
<!-- ktf -->
<!-- To comply with the format -->
<!-- Link sign - Don't Found a better way :-( - You know a better method? - send me a email -->
>[!NOTE]
>Symbol to mark web external links [![alt text][1]](./README.md)
<!-- spell-checker: disable  -->
<!-- keep the format -->
<!-- make folder and download the link sign vai curl -->
<!-- mkdir -p img && curl --create-dirs --output-dir img -O  "https://raw.githubusercontent.com/MathiasStadler/link_symbol_svg/refs/heads/main/link_symbol.svg"-->
<!-- Link sign - Don't Found a better way :-( - You know a better method? - **send me a email** -->
[1]: ./img/link_symbol.svg
<!-- keep the format -->
