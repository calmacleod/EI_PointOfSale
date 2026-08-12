import { createInertiaApp } from "@inertiajs/svelte"
import Layout from "../layouts/AppLayout.svelte"
import "./application.css"

createInertiaApp({
  pages: "../pages",
  layout: () => Layout,
  defaults: {
    form: {
      forceIndicesArrayFormatInFormData: false,
      withAllErrors: true,
    },
    visitOptions: () => ({ queryStringArrayFormat: "brackets" }),
    future: {
      useScriptElementForInitialPage: true,
      useDataInertiaHeadAttribute: true,
      useDialogForErrorModal: true,
      preserveEqualProps: true,
    },
  },
})
