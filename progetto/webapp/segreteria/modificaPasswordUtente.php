<?php
include '../scripts/db_connection.php';
session_start();

// Controlla se l'utente è loggato, altrimenti reindirizza alla pagina di login
if (!isset($_SESSION['email'])) {
    header("Location: ../login.php");
    exit();
}

// Controlla se il form è stato inviato
if ($_SERVER["REQUEST_METHOD"] == "POST" && isset($_POST['new_password'])) {

    $vecchia_password = $_POST['old_password'];
    $nuova_password = $_POST['new_password'];
    $id_utente = $_POST['id_utente'];

    // Chiamata alla procedura per cambiare la password
    $query_change_password = "CALL universal.change_password($1, $2, $3)";
    $result_change_password = pg_query_params($conn, $query_change_password, array($id_utente, $vecchia_password, $nuova_password));

    if (!$result_change_password) {
        echo '<script type="text/javascript">alert("Error: Errore durante il cambio password");window.location = "./modificaPasswordUtente.php";</script>';
        exit;
    }

    echo '<script type="text/javascript">alert("Error: Password cambiata con successo");window.location = "./modificaPasswordUtente.php"; </script>';
}
?>

<!DOCTYPE html>
<html>
<head>
    <title>Modifica Password</title>
    <link rel="stylesheet" type="text/css" href="./changePassword.css">
</head>
<body>
    <div class="sfondo">
        <div class="contenitore">
        <div class="logo">
                <a class="nav-link" id="uni" aria-current="page" href="../login.php">Universal</a>
                <br>
                <br>
                <br>
        </div>
        <br>
        <br>
        <div class="home">
                    <a class="nav-link" id="home" aria-current="page" href="./index.php">Home</a>
            </div>
        <div class="titolo"><h3>Modifica Password</h3></div>
        <div class="modifica">
        <form method="POST" action="">
        <div class="form-group">
    <input type='hidden' name='id_utente' value="<?php echo $_POST['id_utente']; ?>" />
    <input id="old_password" class="form-control input-lg typeahead top-buffer-s" name="old_password" type="password" class="form-control bg-transparent rounded-0 my-4" placeholder="Old Password" aria-label="Email" aria-describedby="basic-addon1">
    <br>
    <input id="new_password" class="form-control input-lg pass" name="new_password" type="password" class="form-control  bg-transparent rounded-0 my-4" placeholder="New Password" aria-label="Username" aria-describedby="basic-addon1">
    <br>
    <button type="submit" class="btn btn-primary btn-lg btn-block">Change</button>
</div>

</form> 
                
    
        </div>
        

        </div>
                    

        </div>
        
    </div>

    <footer>
        <div>
            Università degli studi di Universal
        </div>
        <div>
            Made by Jack during the small hours
        </div>
        <div>
            <a href="https://google.com">Assistenza Universal</a>
            <br>
        </div>
    </footer>

    

</body>
</html>
