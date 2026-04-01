<script setup lang="ts">
definePageMeta({
  middleware: [
    function (to, from) {
      return navigateTo('/sign-in')
    }
  ]
})
</script>

<template>
  <div></div>
</template>