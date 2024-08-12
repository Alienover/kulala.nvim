# Using Variables

You can use variables in your HTTP requests.

Create a file with the `.http` extension and write your HTTP requests in it.

```http title="examples.http"
@pokemon=pikachu
@pokemon2=bulbasaur

GET https://pokeapi.co/api/v2/pokemon/{{pokemon}} HTTP/1.1
Accept: application/json

###

GET https://pokeapi.co/api/v2/pokemon/{{pokemon2}} HTTP/1.1
Accept: application/json
```
