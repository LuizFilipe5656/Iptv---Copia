# Configuração Shadcn UI

Após executar `npm install`, execute os seguintes comandos para instalar os componentes Shadcn UI necessários:

```bash
npx shadcn-ui@latest init
```

Durante a inicialização, selecione:
- Style: Default
- Base color: Slate
- CSS variables: Yes

Em seguida, instale os componentes:

```bash
npx shadcn-ui@latest add button
npx shadcn-ui@latest add card
npx shadcn-ui@latest add input
npx shadcn-ui@latest add label
npx shadcn-ui@latest add dialog
npx shadcn-ui@latest add toast
```

Os componentes já foram criados manualmente em `src/components/ui/`, então você pode pular esta etapa se preferir usar os arquivos existentes.
