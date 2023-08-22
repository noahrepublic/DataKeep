"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[764],{3905:(e,t,r)=>{r.d(t,{Zo:()=>p,kt:()=>m});var n=r(67294);function o(e,t,r){return t in e?Object.defineProperty(e,t,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[t]=r,e}function a(e,t){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var n=Object.getOwnPropertySymbols(e);t&&(n=n.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),r.push.apply(r,n)}return r}function i(e){for(var t=1;t<arguments.length;t++){var r=null!=arguments[t]?arguments[t]:{};t%2?a(Object(r),!0).forEach((function(t){o(e,t,r[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):a(Object(r)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(r,t))}))}return e}function s(e,t){if(null==e)return{};var r,n,o=function(e,t){if(null==e)return{};var r,n,o={},a=Object.keys(e);for(n=0;n<a.length;n++)r=a[n],t.indexOf(r)>=0||(o[r]=e[r]);return o}(e,t);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);for(n=0;n<a.length;n++)r=a[n],t.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(o[r]=e[r])}return o}var c=n.createContext({}),l=function(e){var t=n.useContext(c),r=t;return e&&(r="function"==typeof e?e(t):i(i({},t),e)),r},p=function(e){var t=l(e.components);return n.createElement(c.Provider,{value:t},e.children)},u="mdxType",f={inlineCode:"code",wrapper:function(e){var t=e.children;return n.createElement(n.Fragment,{},t)}},d=n.forwardRef((function(e,t){var r=e.components,o=e.mdxType,a=e.originalType,c=e.parentName,p=s(e,["components","mdxType","originalType","parentName"]),u=l(r),d=o,m=u["".concat(c,".").concat(d)]||u[d]||f[d]||a;return r?n.createElement(m,i(i({ref:t},p),{},{components:r})):n.createElement(m,i({ref:t},p))}));function m(e,t){var r=arguments,o=t&&t.mdxType;if("string"==typeof e||o){var a=r.length,i=new Array(a);i[0]=d;var s={};for(var c in t)hasOwnProperty.call(t,c)&&(s[c]=t[c]);s.originalType=e,s[u]="string"==typeof e?e:o,i[1]=s;for(var l=2;l<a;l++)i[l]=r[l];return n.createElement.apply(null,i)}return n.createElement.apply(null,r)}d.displayName="MDXCreateElement"},73714:(e,t,r)=>{r.r(t),r.d(t,{assets:()=>c,contentTitle:()=>i,default:()=>f,frontMatter:()=>a,metadata:()=>s,toc:()=>l});var n=r(87462),o=(r(67294),r(3905));const a={sidebar_position:4},i="DataKeep vs ProfileService",s={unversionedId:"Versus",id:"Versus",title:"DataKeep vs ProfileService",description:"ProfileService the number one datastore module by loleris is a great module. However, not flawless in my opinion which is why DataKeep was born.",source:"@site/docs/Versus.md",sourceDirName:".",slug:"/Versus",permalink:"/DataKeep/docs/Versus",draft:!1,editUrl:"https://github.com/noahrepublic/DataKeep/edit/main/docs/Versus.md",tags:[],version:"current",sidebarPosition:4,frontMatter:{sidebar_position:4},sidebar:"defaultSidebar",previous:{title:"Basic Usage",permalink:"/DataKeep/docs/Usage"}},c={},l=[],p={toc:l},u="wrapper";function f(e){let{components:t,...r}=e;return(0,o.kt)(u,(0,n.Z)({},p,r,{components:t,mdxType:"MDXLayout"}),(0,o.kt)("h1",{id:"datakeep-vs-profileservice"},"DataKeep vs ProfileService"),(0,o.kt)("p",null,"ProfileService the number one datastore module by loleris is a great module. However, not flawless in my opinion which is why DataKeep was born."),(0,o.kt)("p",null,"Flaws in ProfileService:"),(0,o.kt)("ul",null,(0,o.kt)("li",{parentName:"ul"},"Profile does not automatically clean up internal connections, making the developer have to perform inconvenient clean ups"),(0,o.kt)("li",{parentName:"ul"},"ProfileService async calls make it difficult to wait for Profiles to be loaded. Causing weird patterns when waiting for Profiles, DataKeep is promise based"),(0,o.kt)("li",{parentName:"ul"},"Shorter, cleaner, scripts for faster future development, and contributors (vs ProfileService fitting classes inside one script for micro-performance)"),(0,o.kt)("li",{parentName:"ul"},"Type checking, one caveat due to Luau limitations, can not type check what Promises return (shows on documentation)")))}f.isMDXComponent=!0}}]);