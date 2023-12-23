"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[764],{3905:(e,r,t)=>{t.d(r,{Zo:()=>p,kt:()=>m});var n=t(67294);function o(e,r,t){return r in e?Object.defineProperty(e,r,{value:t,enumerable:!0,configurable:!0,writable:!0}):e[r]=t,e}function i(e,r){var t=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);r&&(n=n.filter((function(r){return Object.getOwnPropertyDescriptor(e,r).enumerable}))),t.push.apply(t,n)}return t}function a(e){for(var r=1;r<arguments.length;r++){var t=null!=arguments[r]?arguments[r]:{};r%2?i(Object(t),!0).forEach((function(r){o(e,r,t[r])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(t)):i(Object(t)).forEach((function(r){Object.defineProperty(e,r,Object.getOwnPropertyDescriptor(t,r))}))}return e}function s(e,r){if(null==e)return{};var t,n,o=function(e,r){if(null==e)return{};var t,n,o={},i=Object.keys(e);for(n=0;n<i.length;n++)t=i[n],r.indexOf(t)>=0||(o[t]=e[t]);return o}(e,r);if(Object.getOwnPropertySymbols){var i=Object.getOwnPropertySymbols(e);for(n=0;n<i.length;n++)t=i[n],r.indexOf(t)>=0||Object.prototype.propertyIsEnumerable.call(e,t)&&(o[t]=e[t])}return o}var c=n.createContext({}),l=function(e){var r=n.useContext(c),t=r;return e&&(t="function"==typeof e?e(r):a(a({},r),e)),t},p=function(e){var r=l(e.components);return n.createElement(c.Provider,{value:r},e.children)},u="mdxType",f={inlineCode:"code",wrapper:function(e){var r=e.children;return n.createElement(n.Fragment,{},r)}},d=n.forwardRef((function(e,r){var t=e.components,o=e.mdxType,i=e.originalType,c=e.parentName,p=s(e,["components","mdxType","originalType","parentName"]),u=l(t),d=o,m=u["".concat(c,".").concat(d)]||u[d]||f[d]||i;return t?n.createElement(m,a(a({ref:r},p),{},{components:t})):n.createElement(m,a({ref:r},p))}));function m(e,r){var t=arguments,o=r&&r.mdxType;if("string"==typeof e||o){var i=t.length,a=new Array(i);a[0]=d;var s={};for(var c in r)hasOwnProperty.call(r,c)&&(s[c]=r[c]);s.originalType=e,s[u]="string"==typeof e?e:o,a[1]=s;for(var l=2;l<i;l++)a[l]=t[l];return n.createElement.apply(null,a)}return n.createElement.apply(null,t)}d.displayName="MDXCreateElement"},73714:(e,r,t)=>{t.r(r),t.d(r,{assets:()=>c,contentTitle:()=>a,default:()=>f,frontMatter:()=>i,metadata:()=>s,toc:()=>l});var n=t(87462),o=(t(67294),t(3905));const i={sidebar_position:4},a="DataKeep vs ProfileService",s={unversionedId:"Versus",id:"Versus",title:"DataKeep vs ProfileService",description:"ProfileService by loleris is a great module. However, there are some minor opinionated flaws:",source:"@site/docs/Versus.md",sourceDirName:".",slug:"/Versus",permalink:"/DataKeep/docs/Versus",draft:!1,editUrl:"https://github.com/noahrepublic/DataKeep/edit/main/docs/Versus.md",tags:[],version:"current",sidebarPosition:4,frontMatter:{sidebar_position:4},sidebar:"defaultSidebar",previous:{title:"Basic Usage",permalink:"/DataKeep/docs/Usage"},next:{title:"WriteLib",permalink:"/DataKeep/docs/WriteLib"}},c={},l=[],p={toc:l},u="wrapper";function f(e){let{components:r,...t}=e;return(0,o.kt)(u,(0,n.Z)({},p,t,{components:r,mdxType:"MDXLayout"}),(0,o.kt)("h1",{id:"datakeep-vs-profileservice"},"DataKeep vs ProfileService"),(0,o.kt)("p",null,"ProfileService by loleris is a great module. However, there are some minor opinionated flaws:"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"Profile does not automatically clean up internal connections, making the developer have to perform inconvenient clean ups"),(0,o.kt)("li",{parentName:"ul"},"ProfileService async calls make it difficult to wait for Profiles to be loaded. Causing weird patterns when waiting for Profiles, DataKeep is promise based"),(0,o.kt)("li",{parentName:"ul"},"Shorter, cleaner, scripts for faster future development, and contributors (vs ProfileService fitting classes inside one script for micro-performance)"),(0,o.kt)("li",{parentName:"ul"},"Type checking. There is one caveat due to Luau limitations, can not type check what Promises return (but shows on documentation)")))}f.isMDXComponent=!0}}]);