"use strict";(self.webpackChunkdocs=self.webpackChunkdocs||[]).push([[671],{3905:(e,t,r)=>{r.d(t,{Zo:()=>c,kt:()=>f});var a=r(67294);function n(e,t,r){return t in e?Object.defineProperty(e,t,{value:r,enumerable:!0,configurable:!0,writable:!0}):e[t]=r,e}function o(e,t){var r=Object.keys(e);if(Object.getOwnPropertySymbols){var a=Object.getOwnPropertySymbols(e);t&&(a=a.filter((function(t){return Object.getOwnPropertyDescriptor(e,t).enumerable}))),r.push.apply(r,a)}return r}function i(e){for(var t=1;t<arguments.length;t++){var r=null!=arguments[t]?arguments[t]:{};t%2?o(Object(r),!0).forEach((function(t){n(e,t,r[t])})):Object.getOwnPropertyDescriptors?Object.defineProperties(e,Object.getOwnPropertyDescriptors(r)):o(Object(r)).forEach((function(t){Object.defineProperty(e,t,Object.getOwnPropertyDescriptor(r,t))}))}return e}function l(e,t){if(null==e)return{};var r,a,n=function(e,t){if(null==e)return{};var r,a,n={},o=Object.keys(e);for(a=0;a<o.length;a++)r=o[a],t.indexOf(r)>=0||(n[r]=e[r]);return n}(e,t);if(Object.getOwnPropertySymbols){var o=Object.getOwnPropertySymbols(e);for(a=0;a<o.length;a++)r=o[a],t.indexOf(r)>=0||Object.prototype.propertyIsEnumerable.call(e,r)&&(n[r]=e[r])}return n}var s=a.createContext({}),p=function(e){var t=a.useContext(s),r=t;return e&&(r="function"==typeof e?e(t):i(i({},t),e)),r},c=function(e){var t=p(e.components);return a.createElement(s.Provider,{value:t},e.children)},u="mdxType",d={inlineCode:"code",wrapper:function(e){var t=e.children;return a.createElement(a.Fragment,{},t)}},m=a.forwardRef((function(e,t){var r=e.components,n=e.mdxType,o=e.originalType,s=e.parentName,c=l(e,["components","mdxType","originalType","parentName"]),u=p(r),m=n,f=u["".concat(s,".").concat(m)]||u[m]||d[m]||o;return r?a.createElement(f,i(i({ref:t},c),{},{components:r})):a.createElement(f,i({ref:t},c))}));function f(e,t){var r=arguments,n=t&&t.mdxType;if("string"==typeof e||n){var o=r.length,i=new Array(o);i[0]=m;var l={};for(var s in t)hasOwnProperty.call(t,s)&&(l[s]=t[s]);l.originalType=e,l[u]="string"==typeof e?e:n,i[1]=l;for(var p=2;p<o;p++)i[p]=r[p];return a.createElement.apply(null,i)}return a.createElement.apply(null,r)}m.displayName="MDXCreateElement"},59881:(e,t,r)=>{r.r(t),r.d(t,{assets:()=>s,contentTitle:()=>i,default:()=>d,frontMatter:()=>o,metadata:()=>l,toc:()=>p});var a=r(87462),n=(r(67294),r(3905));const o={sidebar_position:1},i="Getting Started",l={unversionedId:"intro",id:"intro",title:"Getting Started",description:"What is DataKeep?",source:"@site/docs/intro.md",sourceDirName:".",slug:"/intro",permalink:"/DataKeep/docs/intro",draft:!1,editUrl:"https://github.com/noahrepublic/DataKeep/edit/main/docs/intro.md",tags:[],version:"current",sidebarPosition:1,frontMatter:{sidebar_position:1},sidebar:"defaultSidebar",next:{title:"Installation",permalink:"/DataKeep/docs/Installation"}},s={},p=[{value:"What is DataKeep?",id:"what-is-datakeep",level:2},{value:"Why DataKeep?",id:"why-datakeep",level:2},{value:"Ready to get started?",id:"ready-to-get-started",level:3}],c={toc:p},u="wrapper";function d(e){let{components:t,...r}=e;return(0,n.kt)(u,(0,a.Z)({},c,r,{components:t,mdxType:"MDXLayout"}),(0,n.kt)("h1",{id:"getting-started"},"Getting Started"),(0,n.kt)("h2",{id:"what-is-datakeep"},"What is DataKeep?"),(0,n.kt)("p",null,"DataKeep is a module that loads and autosaves to datastores"),(0,n.kt)("p",null,"A Keep Datastore (Holds datastore saving information & methods) automatically saves itself and cleans up for you."),(0,n.kt)("h2",{id:"why-datakeep"},"Why DataKeep?"),(0,n.kt)("ul",null,(0,n.kt)("li",{parentName:"ul"},"No getter/setter functions, allows ability to write your own wrapper interface"),(0,n.kt)("li",{parentName:"ul"},"Session Locking, prevents other servers from editing directly to prevent duplication exploits or overwriting data loss"),(0,n.kt)("li",{parentName:"ul"},"GlobalUpdates to communicate to offline Keeps"),(0,n.kt)("li",{parentName:"ul"},"Similar API to previous data ModuleScript ",(0,n.kt)("a",{parentName:"li",href:"https://github.com/MadStudioRoblox/ProfileService"},"ProfileService")," allowing easy to pick up"),(0,n.kt)("li",{parentName:"ul"},"Promised base for control over exactly when things complete"),(0,n.kt)("li",{parentName:"ul"},"Actively maintained, and accepting contributions")),(0,n.kt)("h3",{id:"ready-to-get-started"},"Ready to get started?"),(0,n.kt)("ul",null,(0,n.kt)("li",{parentName:"ul"},(0,n.kt)("a",{parentName:"li",href:"/docs/Installation"},(0,n.kt)("strong",{parentName:"a"},"Installation"))),(0,n.kt)("li",{parentName:"ul"},(0,n.kt)("a",{parentName:"li",href:"/api/Store"},(0,n.kt)("strong",{parentName:"a"},"API Documentation")))))}d.isMDXComponent=!0}}]);