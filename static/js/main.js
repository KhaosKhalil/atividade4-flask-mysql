// Menu responsivo (celular)
const botaoMenu = document.getElementById("menu-toggle");
const menu = document.getElementById("menu");
if (botaoMenu && menu) {
    botaoMenu.addEventListener("click", () => {
        const aberto = menu.classList.toggle("aberto");
        botaoMenu.setAttribute("aria-expanded", aberto);
    });
}

// Relogio da pagina inicial
const relogio = document.getElementById("relogio");
if (relogio) {
    const atualizar = () => {
        relogio.textContent = new Date().toLocaleTimeString("pt-BR");
    };
    atualizar();
    setInterval(atualizar, 1000);
}
