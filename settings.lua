-- Pagina em /whip -> Settings -> Norte Staff. Os valores guardados escrevem por cima de Config.
-- O cliente le Config.Noclip a cada frame e o servidor le o resto em cada comando,
-- por isso todas as mudancas valem logo, sem restart.

Whip.configPage({
    label = 'Norte Staff',
    groups = {
        { label = 'Noclip', settings = {
            { key = 'Noclip.normal', type = 'number', min = 0.5, max = 200, step = 0.5, unit = 'm/s',
              label = 'Velocidade normal' },
            { key = 'Noclip.rapido', type = 'number', min = 0.5, max = 500, step = 0.5, unit = 'm/s',
              label = 'Velocidade com Shift' },
            { key = 'Noclip.lento', type = 'number', min = 0.1, max = 50, step = 0.1, unit = 'm/s',
              label = 'Velocidade com Alt' },
        } },
        { label = 'God', settings = {
            { key = 'GodIntervalo', type = 'int', min = 250, max = 10000, step = 250, unit = 'ms',
              label = 'Intervalo do /god', help = 'De quanto em quanto tempo o colete, a fome e a sede voltam ao maximo' },
        } },
        { label = 'Veiculos', settings = {
            { key = 'RaioDv', type = 'number', min = 1, max = 50, step = 0.5, unit = 'm',
              label = 'Raio do /dv', help = 'Distancia a que o /dv procura um carro quando nao estas dentro de um' },
            { key = 'CarroDuracao', type = 'int', min = 30, max = 86400, step = 30, unit = 's',
              nullable = true, emptyLabel = 'sem limite',
              label = 'Duracao do /car', help = 'Vazio: o carro so sai com /dv, com um /car novo ou ao sair do servidor' },
        } },
        { label = 'Servidor', settings = {
            { key = 'AnuncioMax', type = 'int', min = 10, max = 500, step = 10,
              label = 'Tamanho maximo do /anuncio', help = 'Numero de caracteres. O resto e cortado' },
        } },
    },
})
